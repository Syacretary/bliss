import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../onboarding/models.dart';
import 'dash_widgets.dart';
import 'dashboard_repository.dart';

enum ChatKind { ai, needsYou }

class RuntimeConsoleLine {
  const RuntimeConsoleLine({
    required this.sequence,
    required this.timestamp,
    required this.level,
    required this.message,
  });

  final int sequence;
  final DateTime timestamp;
  final String level;
  final String message;
}

class ChatItem {
  const ChatItem(
      this.name, this.message, this.reply, this.time, this.mood, this.kind,
      {this.id, this.timestamp, this.messageCount = 0, this.takenOver = false});
  final String name, message, time, mood;
  final String? reply;
  final ChatKind kind;
  final String? id;
  final int? timestamp;
  final int messageCount;
  final bool takenOver;
}

enum KnowledgeKind { faq, document, image, text }

class KnowledgeItem {
  KnowledgeItem({
    required this.title,
    required this.content,
    required this.kind,
    this.fileName,
    this.fileSize,
  });
  String title, content;
  KnowledgeKind kind;
  String? fileName;
  String? fileSize;
}

class WaAccount {
  WaAccount({required this.phone, required this.name, this.isConnected = true});
  String phone;
  String name;
  bool isConnected;
}

class PluginItem {
  PluginItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.enabled = true,
    this.installed = false,
    this.configured = false,
    this.settings = const {},
    this.settingsSchema = const [],
    this.permissions = const [],
  });
  String id, name, description;
  IconData icon;
  bool enabled;
  bool installed, configured;
  Map<String, Object?> settings;
  List<Map<String, Object?>> settingsSchema;
  List<String> permissions;

  factory PluginItem.fromJson(Map<String, Object?> json) {
    final id = json['id']?.toString() ?? '';
    final schema = json['settingsSchema'];
    final settings = json['settings'];
    return PluginItem(
      id: id,
      name: json['name']?.toString() ?? id,
      description: json['description']?.toString() ?? '',
      icon: id == 'autotyping'
          ? Icons.keyboard_alt_outlined
          : Icons.extension_outlined,
      installed: json['installed'] == true,
      enabled: json['enabled'] == true,
      configured: (settings is Map && settings['configured'] == true),
      settings:
          settings is Map ? Map<String, Object?>.from(settings) : const {},
      settingsSchema: schema is List
          ? schema
              .whereType<Map>()
              .map((item) => Map<String, Object?>.from(item))
              .toList()
          : const [],
      permissions: json['permissions'] is List
          ? (json['permissions'] as List).whereType<String>().toList()
          : const [],
    );
  }
}

class CustomCommand {
  CustomCommand({
    required this.trigger,
    required this.response,
    this.enabled = true,
  });
  String trigger;
  String response;
  bool enabled;
}

/// State dashboard.
class DashState extends ChangeNotifier {
  DashState({
    this.title = 'Bliss CS',
    int toneIndex = 1,
    this.provider = 'Google / Gemini',
    this.purpose = Purpose.customerService,
    this.customTone,
    this.apiKey = '',
    String? linkedPhone,
    this.developerMockMode = false,
    this.repository,
  })  : _tone = toneIndex,
        waAccounts = [
          WaAccount(
            phone: linkedPhone ?? 'Belum tertaut',
            name: linkedPhone == null ? 'WhatsApp' : 'Nomor utama',
            isConnected: false,
          ),
        ] {
    // A saved phone number proves the account was linked before, not that the
    // local Node runtime is currently connected. The first status fetch is truth.
    botOn = developerMockMode;
    _initKnowledge();
  }

  factory DashState.fromAnswers(
    Answers a, {
    String? linkedPhone,
    DashboardRepository? repository,
  }) {
    final t = a.tone;
    final pur = a.purpose ?? Purpose.customerService;
    String defaultTitle = a.businessName ?? 'Bliss';
    if (a.businessName == null || a.businessName!.isEmpty) {
      defaultTitle = pur == Purpose.personal
          ? 'Bliss Personal'
          : (pur == Purpose.community ? 'Bliss Komunitas' : 'Bliss CS');
    }
    return DashState(
      title: defaultTitle,
      toneIndex: t == 'Formal' ? 0 : (t == 'To the point' ? 2 : 1),
      provider: a.provider ?? 'Google / Gemini',
      purpose: pur,
      linkedPhone: linkedPhone,
      developerMockMode: a.businessName?.trim() == 'Develop999',
      repository: repository,
    );
  }

  final String title;
  final bool developerMockMode;
  final DashboardRepository? repository;

  WhatsAppConnector get connector => (repository is WhatsAppConnector)
      ? (repository as WhatsAppConnector)
      : FakeConnector();

  Purpose purpose;
  Timer? _pause;

  // ── Kontrol ──
  bool botOn = false;
  bool botTransitioning = false;
  String runtimeStatus = 'idle';
  String? botActionError;
  bool consoleMode = false;
  int _tone; // 0: Formal, 1: Ramah, 2: To the point, 3: Kustom
  int get toneIndex => _tone;
  String? customTone;
  String apiKey;

  RangeValues hours = const RangeValues(8, 21);
  final Set<int> days = {0, 1, 2, 3, 4, 5, 6};
  String provider;
  int range = 0; // 0 hari ini, 1 7 hari
  final Set<int> takenOver = {};
  final List<RuntimeConsoleLine> _consoleLines = [];
  int _consoleSequence = 0;
  DashboardAnalytics? _analytics;
  List<ChatItem> _liveChats = [];
  bool dashboardLoading = false;
  bool loggingEnabled = true;
  bool _loggingPreferenceLoaded = false;
  String? dashboardError;
  StreamSubscription<Map<String, Object?>>? _runtimeEvents;
  bool _eventTransportLost = false;
  Timer? _refreshTimer;
  bool _refreshPending = false;
  bool _disposed = false;
  bool _runtimeConfigurationLoaded = false;
  final Set<String> _configuredProviders = {};

  bool get providerCredentialConfigured =>
      _configuredProviders.contains(providerIds[provider]);

  // ── Multi WA Accounts ──
  final List<WaAccount> waAccounts;
  int activeWaIndex = 0;
  WaAccount get activeWa => waAccounts[activeWaIndex];

  // ── Knowledge Base ──
  final List<KnowledgeItem> knowledgeBase = [];

  void _initKnowledge() {
    if (!developerMockMode) return;
    knowledgeBase.addAll([
      KnowledgeItem(
          title: 'Jam Buka Toko',
          content: 'Setiap hari 08.00–21.00 WIB.',
          kind: KnowledgeKind.faq),
      KnowledgeItem(
          title: 'Metode Pembayaran COD',
          content: 'Tersedia untuk pengiriman dalam kota.',
          kind: KnowledgeKind.faq),
      KnowledgeItem(
          title: 'Brosur & Katalog Produk',
          content: 'Contoh dokumen referensi.',
          kind: KnowledgeKind.document,
          fileName: 'Katalog_Bliss.pdf',
          fileSize: '1.4 MB'),
      KnowledgeItem(
          title: 'Foto Menu / Varian Produk',
          content: 'Koleksi gambar menu minuman dan makanan.',
          kind: KnowledgeKind.image,
          fileName: 'Menu_Varian_Coffee.jpg',
          fileSize: '850 KB'),
      KnowledgeItem(
          title: 'Kebijakan Pengembalian',
          content:
              'Barang rusak dapat diklaim max 2x24 jam dengan video unboxing.',
          kind: KnowledgeKind.text),
    ]);
    customCommands.addAll([
      CustomCommand(
          trigger: '!promo',
          response: 'Contoh balasan promo untuk pratinjau.',
          enabled: true),
      CustomCommand(
          trigger: '/jadwal',
          response: 'Contoh balasan jadwal untuk pratinjau.',
          enabled: true),
    ]);
  }

  static const providers = [
    'Google / Gemini',
    'OpenAI / ChatGPT',
    'Anthropic / Claude',
    'Opensource / Deepseek',
    'Groq'
  ];
  static const freeProviders = <String>{};

  static const defaultProviderModels = {
    'OpenAI / ChatGPT': 'GPT-6 Luna',
    'Anthropic / Claude': 'Claude Haiku 5.5',
    'Google / Gemini': 'Gemini 3.1 Flash-Lite',
    'Opensource / Deepseek': 'DeepSeek-V4-Flash',
    'Groq': 'GPT-OSS 20B',
  };

  static const defaultProviderModelIds = {
    'OpenAI / ChatGPT': 'gpt-6-luna',
    'Anthropic / Claude': 'claude-haiku-5-5',
    'Google / Gemini': 'gemini-3.1-flash-lite',
    'Opensource / Deepseek': 'deepseek-flash',
    'Groq': 'openai/gpt-oss-20b',
  };

  static const providerIds = {
    'OpenAI / ChatGPT': 'openai',
    'Anthropic / Claude': 'anthropic',
    'Google / Gemini': 'gemini',
    'Opensource / Deepseek': 'deepseek',
    'Groq': 'groq',
  };

  static String getDefaultModel(String p) =>
      defaultProviderModels[p] ?? 'Gemini 3.1 Flash-Lite';

  final Map<String, String> _providerModels = {};

  String getModelForProvider(String p) => _providerModels[p] ?? '';

  String getModelIdForProvider(String p) =>
      _canonicalModelId(p, getModelForProvider(p).trim());

  static String _canonicalModelId(String provider, String configured) {
    if (configured.isEmpty) {
      return defaultProviderModelIds[provider] ?? 'gemini-3.1-flash-lite';
    }
    final normalized = configured.toLowerCase().replaceAll('_', '-');
    const aliases = {
      'Google / Gemini': {'gemini 3.1 flash-lite': 'gemini-3.1-flash-lite'},
      'OpenAI / ChatGPT': {'gpt-6 luna': 'gpt-6-luna'},
      'Anthropic / Claude': {'claude haiku 5.5': 'claude-haiku-5-5'},
      'Opensource / Deepseek': {'deepseek-v4-flash': 'deepseek-flash'},
      'Groq': {'gpt-oss 20b': 'openai/gpt-oss-20b'},
    };
    return aliases[provider]?[normalized] ?? configured;
  }

  bool allowExternalProcessing = false;
  bool savingBotConfiguration = false;
  bool providerConfigurationSaved = false;
  String? configurationSaveError;
  bool get runtimeConfigurationLoaded => _runtimeConfigurationLoaded;

  Future<void> saveBotConfiguration() async {
    final source = repository;
    if (source == null) {
      _n(() => configurationSaveError =
          'Penyimpanan konfigurasi hanya tersedia di runtime Android.');
      return;
    }
    _n(() {
      savingBotConfiguration = true;
      configurationSaveError = null;
    });
    try {
      await source.configureBot(
        configuration: runtimeConfiguration(),
        providerId: providerIds[provider] ?? 'gemini',
        apiKey: apiKey,
      );
      _n(() {
        providerConfigurationSaved = true;
        _runtimeConfigurationLoaded = true;
        final id = providerIds[provider];
        if (id != null && apiKey.trim().isNotEmpty)
          _configuredProviders.add(id);
      });
    } catch (error) {
      _n(() => configurationSaveError = error is StateError
          ? error.message
          : 'Konfigurasi belum tersimpan. Periksa koneksi runtime.');
    } finally {
      _n(() => savingBotConfiguration = false);
    }
  }

  Map<String, Object?> runtimeConfiguration() => {
        'schemaVersion': 2,
        'profile': {
          'purpose': switch (purpose) {
            Purpose.personal => 'personal',
            Purpose.community => 'community',
            Purpose.customerService => 'customerService',
            _ => 'other',
          },
          'businessName': title,
          'businessHours': _businessHoursDescription(),
        },
        'style': {
          'preset': switch (_tone) {
            0 => 'formal',
            2 => 'concise',
            3 => 'custom',
            _ => 'friendly',
          },
          'customText': customTone ?? '',
        },
        'knowledge': knowledgeBase
            .map((item) => <String, Object?>{
                  'kind': item.kind.name,
                  'title': item.title,
                  'content': item.content,
                  if (item.fileName != null) 'fileName': item.fileName,
                })
            .toList(),
        'behavior': {
          'autoReply': true,
          'cooldownSeconds': 15,
          'maxReplyLength': 1000,
        },
        'provider': {
          'id': providerIds[provider] ?? 'gemini',
          'model': getModelIdForProvider(provider),
        },
        'assistant': {
          'displayName': 'Bliss',
          'defaultReply':
              'Halo! Terima kasih sudah menghubungi {{businessName}}. Ada yang bisa kami bantu?',
          'rules': const <Object?>[],
        },
        'privacy': {
          'allowExternalProcessing': allowExternalProcessing,
          'logConversations': true,
          'retentionDays': 30,
        },
        'commands': const <Object?>[],
        'plugins': plugins
            .map((plugin) => <String, Object?>{
                  'id': plugin.id,
                  'enabled': plugin.enabled,
                  'settings': plugin.settings,
                })
            .toList(),
      };

  String _businessHoursDescription() {
    const weekdayNames = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    String hour(double value) {
      final totalMinutes = (value * 60).round();
      final hoursPart = (totalMinutes ~/ 60).toString().padLeft(2, '0');
      final minutesPart = (totalMinutes % 60).toString().padLeft(2, '0');
      return '$hoursPart.$minutesPart';
    }

    final selectedDays = days.toList()..sort();
    final readableDays = days.length == 7
        ? 'Setiap hari'
        : selectedDays.map((index) => weekdayNames[index]).join(', ');
    return '$readableDays, ${hour(hours.start)}–${hour(hours.end)} WIB';
  }

  void setModelForProvider(String p, String model) => _n(() {
        _providerModels[p] = model;
        providerConfigurationSaved = false;
      });

  void _n(void Function() f) {
    if (_disposed) return;
    f();
    notifyListeners();
  }

  Future<void> toggleBot([bool? v]) async {
    final target = v ?? !botOn;
    if (target == botOn || botTransitioning || dashboardLoading) return;
    _pause?.cancel();
    if (developerMockMode) {
      _n(() {
        botOn = target;
        botActionError = null;
      });
      return;
    }
    final source = repository;
    if (source == null) {
      _n(() => botActionError =
          'Kontrol bot hanya tersedia pada perangkat Android yang menjalankan runtime Bliss.');
      return;
    }
    _n(() {
      botTransitioning = true;
      botActionError = null;
    });
    try {
      if (target) {
        await source.configureBot(
          configuration: runtimeConfiguration(),
          providerId: providerIds[provider] ?? 'gemini',
          apiKey: apiKey,
        );
        _runtimeConfigurationLoaded = true;
        providerConfigurationSaved = true;
        final id = providerIds[provider];
        if (id != null && apiKey.trim().isNotEmpty)
          _configuredProviders.add(id);
        await source.startBot();
      } else {
        await source.stopBot();
      }
      await refresh();
      if (!target) {
        _n(() => botOn = false);
      } else if (!botOn) {
        _n(() => botActionError =
            'Runtime dimulai, tetapi WhatsApp belum tersambung. Periksa Console.');
      }
    } catch (error) {
      _n(() => botActionError = error is StateError
          ? error.message
          : 'Perintah bot gagal. Periksa koneksi runtime lalu coba lagi.');
      // Sync the switch with the process if the command raced a status change.
      await refresh();
    } finally {
      _n(() => botTransitioning = false);
    }
  }

  void showConsole() => _n(() => consoleMode = true);
  void showChatLogs() => _n(() => consoleMode = false);

  Future<void> pauseOneHour() async {
    if (!botOn || botTransitioning || dashboardLoading) return;
    _pause?.cancel();
    await toggleBot(false);
    if (!botOn) {
      _pause = Timer(const Duration(hours: 1), () => toggleBot(true));
    }
  }

  void setPurpose(Purpose p) => _n(() => purpose = p);

  void setTone(int i) => _n(() {
        _tone = i;
        providerConfigurationSaved = false;
      });

  void setCustomTone(String? text) => _n(() {
        customTone = text;
        _tone = 3;
        providerConfigurationSaved = false;
      });

  // ── Plugins & Custom Commands ──
  final List<PluginItem> plugins = [];
  final List<PluginItem> pluginCatalog = [];

  final List<CustomCommand> customCommands = [];

  Future<void> installPlugin(
      PluginItem plugin, Map<String, Object?> settings) async {
    if (plugins.any((item) => item.id == plugin.id)) return;
    final installed = PluginItem(
      id: plugin.id,
      name: plugin.name,
      description: plugin.description,
      icon: plugin.icon,
      enabled: false,
      installed: true,
      configured: true,
      settings: {...settings, 'configured': true},
      settingsSchema: plugin.settingsSchema,
      permissions: plugin.permissions,
    );
    _n(() => plugins.add(installed));
    try {
      await _persistPlugins();
      _n(() {
        final catalogItem =
            pluginCatalog.where((item) => item.id == plugin.id).firstOrNull;
        if (catalogItem != null) catalogItem.installed = true;
      });
    } catch (_) {
      _n(() => plugins.removeWhere((item) => item.id == plugin.id));
      rethrow;
    }
  }

  Future<void> configurePlugin(int index, Map<String, Object?> settings) async {
    final plugin = plugins[index];
    final previous = plugin.settings;
    _n(() {
      plugin.settings = {...settings, 'configured': true};
      plugin.configured = true;
    });
    try {
      await _persistPlugins();
    } catch (_) {
      _n(() {
        plugin.settings = previous;
        plugin.configured = previous['configured'] == true;
      });
      rethrow;
    }
  }

  Future<void> togglePlugin(int index, [bool? val]) async {
    final plugin = plugins[index];
    if (!plugin.configured) return;
    final previous = plugin.enabled;
    _n(() => plugin.enabled = val ?? !plugin.enabled);
    try {
      await _persistPlugins();
      _n(() {
        final catalogItem =
            pluginCatalog.where((item) => item.id == plugin.id).firstOrNull;
        if (catalogItem != null) catalogItem.enabled = plugin.enabled;
      });
    } catch (_) {
      _n(() => plugin.enabled = previous);
      rethrow;
    }
  }

  Future<void> removePlugin(int index) async {
    late PluginItem plugin;
    _n(() => plugin = plugins.removeAt(index));
    try {
      await _persistPlugins();
      _n(() {
        final catalogItem =
            pluginCatalog.where((item) => item.id == plugin.id).firstOrNull;
        if (catalogItem != null) {
          catalogItem.installed = false;
          catalogItem.enabled = false;
        }
      });
    } catch (_) {
      _n(() => plugins.insert(index, plugin));
      rethrow;
    }
  }

  Future<void> _persistPlugins() async {
    final source = repository;
    if (source == null)
      throw StateError(
          'Pengelolaan Plugin Store tersedia saat runtime Android aktif.');
    await source.savePlugins(plugins
        .map((plugin) => <String, Object?>{
              'id': plugin.id,
              'enabled': plugin.enabled,
              'settings': plugin.settings,
            })
        .toList());
    _n(() {});
  }

  void toggleCustomCommand(int index, [bool? val]) => _n(() {
        customCommands[index].enabled = val ?? !customCommands[index].enabled;
      });
  void addCustomCommand(String trigger, String response) => _n(() {
        customCommands.add(CustomCommand(trigger: trigger, response: response));
      });
  void removeCustomCommand(int index) =>
      _n(() => customCommands.removeAt(index));

  void setApiKey(String key) => _n(() {
        apiKey = key;
        providerConfigurationSaved = false;
      });

  void setExternalProcessingConsent(bool value) => _n(() {
        allowExternalProcessing = value;
        providerConfigurationSaved = false;
      });

  void setHours(RangeValues v) => _n(() => hours = v);
  void toggleDay(int d) => _n(() {
        if (days.contains(d)) {
          if (days.length > 1) days.remove(d);
        } else {
          days.add(d);
        }
      });
  void setProvider(String p) => _n(() {
        provider = p;
        apiKey = '';
        providerConfigurationSaved = false;
      });
  void setRange(int r) {
    if (r == range) return;
    _n(() => range = r);
    if (!developerMockMode) unawaited(refresh());
  }

  void takeOver(int i) => _n(() => takenOver.add(i));

  Future<void> refresh() async {
    final source = repository;
    if (developerMockMode || source == null || _disposed) return;
    if (dashboardLoading) {
      _refreshPending = true;
      return;
    }
    _n(() {
      dashboardLoading = true;
      dashboardError = null;
    });
    try {
      _runtimeEvents ??= source.events.listen((event) {
        if (event['type'] == 'transportError') {
          _eventTransportLost = true;
          if (!_disposed) {
            _n(() => dashboardError = event['message']?.toString() ??
                'Kanal status runtime terputus; Bliss sedang menyambung ulang.');
          }
          return;
        }
        if (event['type'] == 'heartbeat') {
          if (_eventTransportLost && !_disposed) {
            _eventTransportLost = false;
            _n(() => dashboardError = null);
          }
          return;
        }
        if (event['type'] == 'status') {
          final status = event['status']?.toString();
          if (status != null && status != runtimeStatus) {
            _n(() {
              runtimeStatus = status;
              if (status == 'connected') {
                botOn = true;
                activeWa.isConnected = true;
                botActionError = null;
              } else {
                botOn = false;
                activeWa.isConnected = false;
              }
            });
          }
        }
        _captureConsoleEvent(event);
        if (event['type'] != 'conversation' && event['type'] != 'status')
          return;
        _refreshTimer?.cancel();
        _refreshTimer = Timer(const Duration(milliseconds: 450), () {
          unawaited(refresh());
        });
      }, onError: (_) {
        if (_disposed) return;
        _eventTransportLost = true;
        _n(() => dashboardError =
            'Koneksi data lokal terputus. Tarik untuk memuat ulang.');
      });
      // Subscribe before opening the stream so the initial server status and
      // transport recovery events cannot be lost on a fast local connection.
      await source.connectEvents();
      final days = range == 0 ? 1 : 7;
      final offset = DateTime.now().timeZoneOffset.inMinutes;
      final values = await Future.wait<Object>([
        source.analytics(days: days, utcOffsetMinutes: offset),
        source.conversations(),
        source.connection(),
        source.botConfiguration(),
        source.configuredProviders(),
        source.pluginStore(),
      ]);
      final analytics = values[0] as DashboardAnalytics;
      final conversations = values[1] as List<DashboardConversation>;
      final connection = values[2] as DashboardConnection;
      final botConfiguration = values[3] as Map<String, Object?>;
      final configuredProviders = values[4] as Set<String>;
      final pluginStore = values[5] as List<Map<String, Object?>>;
      if (_disposed) return;
      _n(() {
        _analytics = analytics;
        loggingEnabled = analytics.loggingEnabled;
        _loggingPreferenceLoaded = true;
        _liveChats = conversations.map((conversation) {
          final name = conversation.displayName.trim();
          return ChatItem(
            name.isEmpty ? 'Kontak' : name,
            conversation.lastMessage,
            null,
            _relativeTime(conversation.lastActivity),
            '',
            conversation.needsHuman ? ChatKind.needsYou : ChatKind.ai,
            id: conversation.id,
            timestamp: conversation.lastActivity,
            messageCount: conversation.messageCount,
            takenOver: conversation.needsHuman,
          );
        }).toList(growable: false);
        takenOver
          ..clear()
          ..addAll([
            for (var i = 0; i < _liveChats.length; i++)
              if (_liveChats[i].takenOver) i,
          ]);
        if (connection.phone != null && connection.phone!.isNotEmpty) {
          activeWa.phone = '+${connection.phone}';
        }
        activeWa.isConnected = connection.isConnected;
        runtimeStatus = connection.status;
        _configuredProviders
          ..clear()
          ..addAll(configuredProviders);
        pluginCatalog
          ..clear()
          ..addAll(pluginStore.map(PluginItem.fromJson));
        plugins
          ..clear()
          ..addAll(pluginCatalog.where((plugin) => plugin.installed));
        if (!_runtimeConfigurationLoaded) {
          _applyRuntimeConfiguration(botConfiguration);
          _runtimeConfigurationLoaded = true;
        }
        botOn = connection.isConnected;
        dashboardLoading = false;
      });
    } catch (error) {
      if (!_disposed) {
        _n(() {
          dashboardError = error is StateError
              ? error.message
              : 'Data bot lokal belum bisa dimuat. Coba lagi.';
          dashboardLoading = false;
        });
      }
    } finally {
      if (_refreshPending && !_disposed) {
        _refreshPending = false;
        unawaited(refresh());
      }
    }
  }

  void _applyRuntimeConfiguration(Map<String, Object?> configuration) {
    final providerConfig = configuration['provider'];
    if (providerConfig is Map<String, Object?>) {
      final id = providerConfig['id'] as String?;
      final selected = providerIds.entries
          .where((entry) => entry.value == id)
          .map((entry) => entry.key)
          .firstOrNull;
      if (selected != null) {
        provider = selected;
        final model = providerConfig['model'] as String? ?? '';
        if (model.isNotEmpty && model != defaultProviderModelIds[selected]) {
          _providerModels[selected] = model;
        }
        providerConfigurationSaved = true;
      }
    }
    final style = configuration['style'];
    if (style is Map<String, Object?>) {
      _tone = switch (style['preset']) {
        'formal' => 0,
        'concise' => 2,
        'custom' => 3,
        _ => 1,
      };
      customTone = style['customText'] as String?;
    }
    final savedKnowledge = configuration['knowledge'];
    if (savedKnowledge is List) {
      knowledgeBase
        ..clear()
        ..addAll(savedKnowledge.whereType<Map>().map((entry) {
          final kindName = entry['kind'] as String? ?? 'text';
          final kind = KnowledgeKind.values.firstWhere(
            (value) => value.name == kindName,
            orElse: () => KnowledgeKind.text,
          );
          return KnowledgeItem(
            title: entry['title'] as String? ?? '',
            content: entry['content'] as String? ?? '',
            kind: kind,
            fileName: entry['fileName'] as String?,
          );
        }));
    }
    final privacy = configuration['privacy'];
    if (privacy is Map<String, Object?>) {
      allowExternalProcessing =
          privacy['allowExternalProcessing'] as bool? ?? false;
    }
  }

  List<RuntimeConsoleLine> get consoleLines {
    if (!developerMockMode) return List.unmodifiable(_consoleLines);
    final now = DateTime.now();
    return [
      RuntimeConsoleLine(
          sequence: -5,
          timestamp: now.subtract(const Duration(minutes: 4)),
          level: 'INFO',
          message: 'WhatsApp runtime initialized'),
      RuntimeConsoleLine(
          sequence: -4,
          timestamp: now.subtract(const Duration(minutes: 3)),
          level: 'OK',
          message: 'Connection status: connected'),
      RuntimeConsoleLine(
          sequence: -3,
          timestamp: now.subtract(const Duration(minutes: 2)),
          level: 'IN',
          message:
              'Pesan masuk dari +62•••••••821 · “Halo, saya ingin bertanya”'),
      RuntimeConsoleLine(
          sequence: -2,
          timestamp: now.subtract(const Duration(minutes: 2)),
          level: 'AI',
          message: 'Balasan bot terkirim · waktu respons 1.2s'),
      RuntimeConsoleLine(
          sequence: -1,
          timestamp: now.subtract(const Duration(minutes: 1)),
          level: 'INFO',
          message: 'Conversation logged locally'),
    ];
  }

  void clearConsole() => _n(_consoleLines.clear);

  void _captureConsoleEvent(Map<String, Object?> event) {
    final type = event['type'];
    final String level;
    final String message;
    if (type == 'status') {
      level = event['status'] == 'error' || event['status'] == 'loggedOut'
          ? 'WARN'
          : 'INFO';
      message = 'WhatsApp status: ${event['status'] ?? 'unknown'}';
    } else if (type == 'conversation') {
      if (!_loggingPreferenceLoaded || !loggingEnabled) return;
      final direction = event['direction']?.toString() ?? 'incoming';
      level = switch (direction) {
        'bot' => 'AI',
        'human' => 'YOU',
        'command' => 'CMD',
        'handoff' => 'HANDOFF',
        _ => 'IN',
      };
      final sender =
          (event['displayName']?.toString().trim().isNotEmpty ?? false)
              ? event['displayName'].toString().trim()
              : 'Kontak';
      final text = (event['text']?.toString() ?? '')
          .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      message = '$sender · $text';
    } else if (type == 'error') {
      level = 'ERROR';
      message = event['message']?.toString() ?? 'Terjadi masalah pada runtime.';
    } else if (type == 'log') {
      final rawLevel = event['level']?.toString() ?? 'INFO';
      level = switch (rawLevel) {
        'WARN' || 'ERROR' => rawLevel,
        _ => 'INFO',
      };
      message = event['message']?.toString() ?? 'Aktivitas runtime.';
    } else if (type == 'pairing') {
      level = 'INFO';
      message = 'Data penautan WhatsApp siap';
    } else {
      return;
    }
    final sanitizedMessage = message
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final safeMessage = sanitizedMessage.length > 500
        ? '${sanitizedMessage.substring(0, 500)}…'
        : sanitizedMessage;
    _n(() {
      _consoleLines.add(RuntimeConsoleLine(
        sequence: _consoleSequence++,
        timestamp: DateTime.now(),
        level: level,
        message: safeMessage,
      ));
      if (_consoleLines.length > 300) _consoleLines.removeAt(0);
    });
  }

  Future<List<DashboardMessage>> loadMessages(String conversationId) async {
    final source = repository;
    if (source == null) return const [];
    return source.messages(conversationId);
  }

  Future<void> setConversationTakeover(int index, bool enabled) async {
    final chat = chats[index];
    if (developerMockMode) {
      _n(() {
        if (enabled) {
          takenOver.add(index);
        } else {
          takenOver.remove(index);
        }
      });
      return;
    }
    final source = repository;
    if (source == null || chat.id == null) return;
    await source.setTakeover(chat.id!, enabled);
    if (_disposed) return;
    _n(() {
      if (enabled) {
        takenOver.add(index);
      } else {
        takenOver.remove(index);
      }
    });
  }

  Future<void> sendReply(String conversationId, String text) async {
    final source = repository;
    if (source == null) throw StateError('Runtime percakapan tidak tersedia.');
    await source.reply(conversationId, text);
    await refresh();
  }

  static String _relativeTime(int timestamp) {
    if (timestamp <= 0) return '';
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
    if (elapsed.inSeconds < 60) return 'Baru';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} mnt';
    if (elapsed.inHours < 24) return '${elapsed.inHours} j';
    if (elapsed.inDays < 7) return '${elapsed.inDays} h';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}';
  }

  // Multi WA Actions
  void switchWaAccount(int index) => _n(() => activeWaIndex = index);
  void addWaAccount(String phone, String name) => _n(() {
        waAccounts.add(WaAccount(phone: phone, name: name, isConnected: false));
        activeWaIndex = waAccounts.length - 1;
      });
  void removeWaAccount(int index) => _n(() {
        if (waAccounts.length > 1) {
          waAccounts.removeAt(index);
          if (activeWaIndex >= waAccounts.length)
            activeWaIndex = waAccounts.length - 1;
        }
      });
  void toggleWaConnection(int index, [bool? status]) => _n(() {
        waAccounts[index].isConnected =
            status ?? !waAccounts[index].isConnected;
      });

  // Knowledge Base Actions
  void addKnowledge(KnowledgeItem item) => _n(() {
        knowledgeBase.add(item);
        providerConfigurationSaved = false;
      });
  void removeKnowledge(int index) => _n(() {
        knowledgeBase.removeAt(index);
        providerConfigurationSaved = false;
      });

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _runtimeEvents?.cancel();
    _pause?.cancel();
    super.dispose();
  }

  // ── Data contoh ──
  static const _today = [
    2,
    1,
    0,
    0,
    0,
    1,
    3,
    6,
    12,
    18,
    22,
    26,
    31,
    24,
    19,
    16,
    14,
    17,
    20,
    15,
    9,
    6,
    4,
    2
  ];
  static const _week = [128, 142, 119, 156, 173, 201, 98];
  static const dayNames = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu'
  ];

  List<int> get hourly => developerMockMode
      ? _today
      : _analytics?.hourlyIncoming ?? List<int>.filled(24, 0);
  List<int> get replySeries => range == 0
      ? (developerMockMode
          ? _today.map((value) => (value * .87).round()).toList()
          : _analytics?.hourlyBotReplies ?? List<int>.filled(24, 0))
      : (developerMockMode
          ? _week.map((value) => (value * .84).round()).toList()
          : _analytics?.daily.map((day) => day.botReplies).toList() ??
              List<int>.filled(7, 0));
  List<int> get conversationSeries => range == 0
      ? (developerMockMode
          ? _today.map((value) => (value * .24).round()).toList()
          : _analytics?.hourlyActiveConversations ?? List<int>.filled(24, 0))
      : (developerMockMode
          ? _week.map((value) => (value * .2).round()).toList()
          : _analytics?.daily.map((day) => day.activeConversations).toList() ??
              List<int>.filled(7, 0));
  List<int> get series => developerMockMode
      ? (range == 0 ? _today : _week)
      : range == 0
          ? hourly
          : (_analytics?.daily.map((day) => day.incoming).toList() ??
              List<int>.filled(7, 0));
  List<String> get labels => developerMockMode
      ? (range == 0
          ? [for (var i = 0; i < 24; i++) i.toString().padLeft(2, '0')]
          : const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
      : range == 0
          ? [for (var i = 0; i < 24; i++) i.toString().padLeft(2, '0')]
          : (_analytics?.daily.map((day) => _weekdayLabel(day.date)).toList() ??
              const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']);
  int get total => series.fold(0, (a, b) => a + b);
  int get incomingMessages =>
      developerMockMode ? total : _analytics?.incomingMessages ?? 0;
  int get botReplies => developerMockMode
      ? (total * autoRate).round()
      : _analytics?.botReplies ?? 0;
  int get humanReplies => developerMockMode ? 0 : _analytics?.humanReplies ?? 0;
  int get responseCount =>
      developerMockMode ? botReplies : _analytics?.responseCount ?? 0;
  int get averageResponseMs =>
      developerMockMode ? 0 : _analytics?.averageResponseMs ?? 0;
  double get autoRate => developerMockMode
      ? (range == 0 ? .87 : .84)
      : (_analytics == null || _analytics!.incomingMessages == 0
          ? 0
          : (_analytics!.botReplies / _analytics!.incomingMessages)
              .clamp(0.0, 1.0));
  int get savedMinutes => developerMockMode
      ? (total * autoRate * .75).round()
      : _analytics?.estimatedMinutesSaved ?? 0;
  int get customers => developerMockMode
      ? (range == 0 ? 64 : 311)
      : _analytics?.activeConversations ?? 0;
  List<int?> get deltas => developerMockMode
      ? (range == 0 ? const [12, 8, 5] : const [6, 3, 9])
      : const [null, null, null];
  List<DashboardTopic> get topics => developerMockMode
      ? const [
          DashboardTopic('Jam buka', 64),
          DashboardTopic('Harga', 52),
          DashboardTopic('Ongkir', 41),
          DashboardTopic('Stok', 27),
          DashboardTopic('Promo', 19),
        ]
      : _analytics?.topics ?? const [];

  static String _weekdayLabel(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return '';
    return const [
      'Sen',
      'Sel',
      'Rab',
      'Kam',
      'Jum',
      'Sab',
      'Min'
    ][parsed.weekday - 1];
  }

  int get peakIndex {
    final s = series;
    var p = 0;
    for (var i = 1; i < s.length; i++) {
      if (s[i] > s[p]) p = i;
    }
    return p;
  }

  int get quietIndex {
    final s = series;
    var p = 0;
    for (var i = 1; i < s.length; i++) {
      if (s[i] < s[p]) p = i;
    }
    return p;
  }

  int get busyStart {
    var best = 0, bestSum = -1;
    final data = hourly;
    for (var i = 0; i < data.length - 1; i++) {
      final s = data[i] + data[i + 1];
      if (s > bestSum) {
        bestSum = s;
        best = i;
      }
    }
    return best;
  }

  bool get busyCovered =>
      hours.start <= busyStart && hours.end >= busyStart + 2;

  // ── Use Case Dynamic Strings ──
  String get heroTitle {
    if (!developerMockMode) {
      return incomingMessages == 0
          ? 'Belum ada pesan tercatat'
          : '$botReplies dari $incomingMessages pesan dibalas bot';
    }
    switch (purpose) {
      case Purpose.personal:
        return 'Bot siap merespon pesan pribadimu 24/7';
      case Purpose.community:
        return 'Bot membantu menjaga ketertiban grup komunitas';
      case Purpose.customerService:
      default:
        return 'Bot menjawab ${(autoRate * 100).round()}% pesan customer sendiri';
    }
  }

  String get heroSub {
    if (!developerMockMode) {
      if (averageResponseMs == 0) return 'Data dihitung dari log di perangkat';
      return 'Rata-rata respon ${(averageResponseMs / 1000).round()} detik';
    }
    switch (purpose) {
      case Purpose.personal:
        return '124 obrolan terbalas otomatis';
      case Purpose.community:
        return '45 anggota baru disambut hari ini';
      case Purpose.customerService:
      default:
        return 'Hemat ${fmtMinutes(savedMinutes.toDouble())} hari ini';
    }
  }

  /// Daily Brief — ringkasan kontekstual 2 baris yang langsung informatif.
  String get dailyBriefTitle {
    if (!developerMockMode) {
      if (!botOn) return 'Bot sedang dijeda';
      if (incomingMessages == 0) return 'Semuanya tenang hari ini';
      if (needsYouCount > 0)
        return '$needsYouCount percakapan menunggu responmu';
      return '$botReplies pesan terbalas otomatis';
    }
    switch (purpose) {
      case Purpose.personal:
        return 'Bot aktif, siap merespons kapanpun';
      case Purpose.community:
        return '${(total * 0.12).round()} anggota disambut hari ini';
      case Purpose.customerService:
      default:
        return '$botReplies pesan terbalas otomatis';
    }
  }

  String get dailyBriefSub {
    if (!developerMockMode) {
      if (!botOn) return 'Aktifkan bot agar tidak ada pesan yang terlewat.';
      if (incomingMessages == 0)
        return 'Grafik akan terbentuk setelah pesan pertama masuk.';
      if (needsYouCount > 0)
        return 'Buka tab Percakapan untuk menindaklanjuti.';
      if (averageResponseMs > 0)
        return 'Rata-rata respons ${(averageResponseMs / 1000).round()} detik. Bisnis kamu berjalan lancar.';
      return 'Data dihitung secara lokal dari log perangkat.';
    }
    switch (purpose) {
      case Purpose.personal:
        return '98% standby — tidak ada pesan yang lolos tanpa balasan.';
      case Purpose.community:
        return 'Komunitas tetap terasa hidup tanpa kamu harus standby 24 jam.';
      case Purpose.customerService:
      default:
        return 'Hemat ${fmtMinutes(savedMinutes.toDouble())} waktu balas manual hari ini.';
    }
  }

  /// Bliss Score: gabungan autoRate + uptime + needsYou ratio (0–100).
  int get blissScore {
    if (!developerMockMode && incomingMessages == 0) return 0;
    // Component 1: auto-reply rate (0-60 points)
    final rateScore = (autoRate * 60).round();
    // Component 2: no pending conversations (0-25 points)
    final total = chats.length;
    final pendingRatio = total == 0 ? 0.0 : needsYouCount / total;
    final pendingScore = ((1 - pendingRatio) * 25).round();
    // Component 3: bot online (0-15 points)
    final onlineScore = botOn ? 15 : 0;
    return (rateScore + pendingScore + onlineScore).clamp(0, 100);
  }

  String get blissScoreLabel {
    final s = blissScore;
    if (!developerMockMode && incomingMessages == 0) return 'Menunggu data';
    if (s >= 85) return 'Excellent';
    if (s >= 65) return 'Cukup Baik';
    if (s >= 40) return 'Perlu Perhatian';
    return 'Perlu Tindakan';
  }

  String get blissScoreTip {
    final s = blissScore;
    if (!developerMockMode && incomingMessages == 0)
      return 'Skor terbentuk setelah pesan pertama masuk.';
    if (s >= 85) return 'Bot kamu hampir sempurna. Pertahankan!';
    if (needsYouCount > 2) return '$needsYouCount percakapan belum ditangani — balas sekarang.';
    if (!botOn) return 'Aktifkan bot untuk menaikkan skor.';
    return 'Tambah pengetahuan bot di Studio untuk meningkatkan skor.';
  }

  /// Milestone: angka "reply" terdekat yang akan dirayakan.
  int? get nextMilestone {
    const milestones = [50, 100, 250, 500, 1000, 2500, 5000, 10000];
    final current = botReplies;
    for (final m in milestones) {
      if (current < m) return m;
    }
    return null;
  }

  /// Apakah baru saja melewati milestone? (dalam ±5 reply dari milestone).
  bool get justHitMilestone {
    const milestones = [50, 100, 250, 500, 1000, 2500, 5000, 10000];
    final current = botReplies;
    return milestones.any((m) => current >= m && current - m < 6);
  }

  String get heroBadgeText {
    if (!developerMockMode && incomingMessages == 0) return 'Belum ada data';
    if (!developerMockMode) return '${(autoRate * 100).round()}% otomatis';
    switch (purpose) {
      case Purpose.personal:
        return '98% Standby';
      case Purpose.community:
        return '89% Moderasi';
      case Purpose.customerService:
      default:
        return '${(autoRate * 100).round()}% otomatis';
    }
  }

  List<(IconData, String, double, int?, List<double>)> get kpis {
    if (!developerMockMode) {
      final incomingValues = series.map((value) => value.toDouble()).toList();
      final replyValues = replySeries.map((value) => value.toDouble()).toList();
      final conversationValues =
          conversationSeries.map((value) => value.toDouble()).toList();
      return [
        (
          Icons.mark_chat_read_rounded,
          'Pesan masuk',
          incomingMessages.toDouble(),
          null,
          incomingValues
        ),
        (
          Icons.timer_rounded,
          'Balasan bot',
          botReplies.toDouble(),
          null,
          replyValues
        ),
        (
          Icons.people_alt_rounded,
          'Percakapan',
          customers.toDouble(),
          null,
          conversationValues
        ),
      ];
    }
    final s = series.map((e) => e.toDouble()).toList();
    final cum = <double>[];
    var run = 0.0;
    for (final e in s) {
      run += e;
      cum.add(run);
    }
    final cust = [
      for (var i = 0; i < s.length; i++) s[i] * .24 + (i.isEven ? 2 : 0)
    ];

    switch (purpose) {
      case Purpose.personal:
        return [
          (Icons.bolt_rounded, 'Respon Kilat', total.toDouble(), deltas[0], s),
          (
            Icons.chat_bubble_outline_rounded,
            'Pribadi',
            total.toDouble(),
            deltas[1],
            cum
          ),
          (Icons.nightlight_round, 'Aktif Malam', 42.0, deltas[2], cust),
        ];
      case Purpose.community:
        return [
          (
            Icons.groups_outlined,
            'Chat Ditangani',
            total.toDouble(),
            deltas[0],
            s
          ),
          (
            Icons.person_add_alt_1_outlined,
            'Anggota',
            customers.toDouble(),
            deltas[1],
            cum
          ),
          (Icons.shield_outlined, 'Aturan Dijaga', 18.0, deltas[2], cust),
        ];
      case Purpose.customerService:
      default:
        return [
          (
            Icons.mark_chat_read_rounded,
            'Dibalas',
            total.toDouble(),
            deltas[0],
            s
          ),
          (
            Icons.timer_rounded,
            'Waktu hemat',
            savedMinutes.toDouble(),
            deltas[1],
            cum
          ),
          (
            Icons.people_alt_rounded,
            'Pelanggan',
            customers.toDouble(),
            deltas[2],
            cust
          ),
        ];
    }
  }

  List<ChatItem> get chats => developerMockMode
      ? const [
          ChatItem('Budi', 'Pesanan saya salah kirim, mau komplain', null,
              '2 mnt', '😠', ChatKind.needsYou),
          ChatItem(
              'Rina',
              'Kak, jam buka sampai jam berapa?',
              'Halo kak! Kami buka sampai jam 9 malam ya 😊',
              '5 mnt',
              '🙂',
              ChatKind.ai),
          ChatItem('Maya', 'Bisa custom ukuran cup nggak?', null, '12 mnt',
              '🤔', ChatKind.needsYou),
          ChatItem(
              'Dimas',
              'Ada promo hari ini?',
              'Ada dong! Diskon 10% untuk pembelian kedua 🎉',
              '31 mnt',
              '😍',
              ChatKind.ai),
          ChatItem(
              'Sari',
              'Bisa kirim ke Sidoarjo?',
              'Bisa banget kak, ongkir mulai Rp8.000 🚚',
              '1 j',
              '🙂',
              ChatKind.ai),
          ChatItem(
              'Eko',
              'Terima kasih, pesanan sudah sampai!',
              'Sama-sama kak, ditunggu order berikutnya 🙏',
              '2 j',
              '😊',
              ChatKind.ai),
        ]
      : _liveChats;

  int get needsYouCount {
    final c = chats;
    var n = 0;
    for (var i = 0; i < c.length; i++) {
      if (c[i].kind == ChatKind.needsYou &&
          !(developerMockMode ? takenOver.contains(i) : c[i].takenOver)) n++;
    }
    return n;
  }

  // ── Persona ──
  static const toneNames = ['Formal', 'Ramah', 'To the point', 'Kustom'];

  Future<String> generateAiResponse(String userPrompt) async {
    final cleanPrompt = userPrompt.trim();
    if (cleanPrompt.isEmpty) return '';

    // 1. Check Custom Commands
    for (final cmd in customCommands) {
      if (cmd.enabled &&
          cleanPrompt.toLowerCase().startsWith(cmd.trigger.toLowerCase())) {
        return '[Perintah Kustom "${cmd.trigger}"]: ${cmd.response}';
      }
    }

    // 2. Check Plugin Rules (e.g. Toxic/Filter Plugin)
    final filterPlugin = plugins.firstWhere(
      (p) => p.id == 'filter',
      orElse: () => PluginItem(
          id: '',
          name: '',
          description: '',
          icon: Icons.shield,
          enabled: false),
    );
    if (filterPlugin.enabled) {
      final badWords = [
        'anjing',
        'babi',
        'bangsat',
        'kontol',
        'memek',
        'asu',
        'goblok',
        'tolol',
        'taik'
      ];
      if (badWords.any((w) => cleanPrompt.toLowerCase().contains(w))) {
        return '[Shield Plugin] Mohon gunakan bahasa yang sopan. $title mengutamakan pelayanan yang ramah dan profesional.';
      }
    }

    // Keep the test prompt aligned with the runtime: studio tone + knowledge only.
    final StringBuffer kbContext = StringBuffer();
    for (final item in knowledgeBase) {
      kbContext.writeln(
          '[${item.kind.name.toUpperCase()}] ${item.title}: ${item.content}');
    }

    final toneDescription = _tone == 0
        ? 'Formal'
        : _tone == 2
            ? 'To the point'
            : _tone == 3
                ? (customTone ?? '')
                : 'Ramah';

    final systemPrompt = '''
Gaya bicara: $toneDescription
Pengetahuan AI:
${kbContext.toString().trimRight()}
''';

    final usesExternalProvider = providerIds.containsKey(provider);
    if (usesExternalProvider && !allowExternalProcessing) {
      return 'Aktifkan persetujuan pemrosesan AI eksternal di Studio sebelum menguji provider. Isi pesan akan dikirim ke ${provider.split(' / ').last}.';
    }
    final source = repository;
    if (usesExternalProvider && source != null && !providerConfigurationSaved) {
      return 'Simpan pengaturan provider dan persetujuan di Studio sebelum menjalankan uji AI.';
    }
    if (usesExternalProvider && apiKey.isEmpty && source == null) {
      return 'API key ${provider.split(' / ').last} belum dimasukkan. Simpan key di Studio, lalu coba lagi.';
    }

    if (usesExternalProvider && source != null) {
      try {
        return await source.testReply(cleanPrompt);
      } catch (error) {
        final detail = error is StateError ? error.message : 'request gagal';
        return 'Uji ${provider.split(' / ').last} gagal: $detail';
      }
    }

    // Call the selected provider with its canonical API model identifier.
    if (apiKey.isNotEmpty) {
      try {
        final aiResult = await _callExternalAiApi(
          provider: provider,
          apiKey: apiKey,
          model: getModelIdForProvider(provider),
          systemPrompt: systemPrompt,
          userPrompt: cleanPrompt,
        );
        if (aiResult.isNotEmpty) return aiResult;
        if (usesExternalProvider) {
          return 'Uji ${provider.split(' / ').last} tidak menghasilkan balasan. Periksa model di Studio.';
        }
      } catch (e) {
        final detail = e is StateError ? e.message : 'request gagal';
        return 'Uji ${provider.split(' / ').last} gagal: $detail';
      }
    }

    // Local template is only used when no remote provider is selected.
    final fallbackText = _generateLocalFallbackReply(cleanPrompt);
    final selectedModel = getModelForProvider(provider).isNotEmpty
        ? getModelForProvider(provider)
        : DashState.getDefaultModel(provider);
    return '$fallbackText\n\n(💡 Petunjuk: Masukkan API Key $provider di Studio Tab untuk menggunakan model AI "$selectedModel" secara live)';
  }

  Future<String> _callExternalAiApi({
    required String provider,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      if (provider.contains('Gemini')) {
        final modelName = model.isNotEmpty ? model : 'gemini-3.1-flash-lite';
        final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent');
        final request = await client.postUrl(url);
        request.headers.contentType = ContentType.json;
        request.headers.set('x-goog-api-key', apiKey);
        final body = jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": userPrompt}
              ]
            }
          ],
          "systemInstruction": {
            "parts": [
              {"text": systemPrompt}
            ]
          }
        });
        request.write(body);
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              return parts[0]['text']?.toString().trim() ?? '';
            }
          }
        } else {
          final errData = jsonDecode(responseBody);
          final errMsg =
              errData['error']?['message'] ?? 'HTTP ${response.statusCode}';
          throw Exception('Gemini: $errMsg');
        }
      } else if (provider.contains('OpenAI') ||
          provider.contains('ChatGPT') ||
          provider.contains('Groq') ||
          provider.contains('Deepseek')) {
        String endpoint = 'https://api.openai.com/v1/chat/completions';
        String modelName = model.isNotEmpty ? model : 'gpt-4o-mini';
        if (provider.contains('Groq')) {
          endpoint = 'https://api.groq.com/openai/v1/chat/completions';
          if (model.isEmpty) modelName = 'llama-3.1-8b-instant';
        } else if (provider.contains('Deepseek')) {
          endpoint = 'https://api.deepseek.com/v1/chat/completions';
          if (model.isEmpty) modelName = 'deepseek-chat';
        }
        final url = Uri.parse(endpoint);
        final request = await client.postUrl(url);
        request.headers.contentType = ContentType.json;
        request.headers.set('Authorization', 'Bearer $apiKey');
        final body = jsonEncode({
          "model": modelName,
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userPrompt}
          ]
        });
        request.write(body);
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody);
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            return choices[0]['message']?['content']?.toString().trim() ?? '';
          }
        } else {
          final errData = jsonDecode(responseBody);
          final errMsg =
              errData['error']?['message'] ?? 'HTTP ${response.statusCode}';
          throw Exception('$provider: $errMsg');
        }
      } else if (provider.contains('Anthropic') ||
          provider.contains('Claude')) {
        final url = Uri.parse('https://api.anthropic.com/v1/messages');
        final request = await client.postUrl(url);
        request.headers.contentType = ContentType.json;
        request.headers.set('x-api-key', apiKey);
        request.headers.set('anthropic-version', '2023-06-01');
        final modelName = model.isNotEmpty ? model : 'claude-3-haiku-20240307';
        final body = jsonEncode({
          "model": modelName,
          "max_tokens": 1024,
          "system": systemPrompt,
          "messages": [
            {"role": "user", "content": userPrompt}
          ]
        });
        request.write(body);
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody);
          final content = data['content'] as List?;
          if (content != null && content.isNotEmpty) {
            return content[0]['text']?.toString().trim() ?? '';
          }
        } else {
          final errData = jsonDecode(responseBody);
          final errMsg =
              errData['error']?['message'] ?? 'HTTP ${response.statusCode}';
          throw Exception('Anthropic: $errMsg');
        }
      }
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
    return '';
  }

  String _generateLocalFallbackReply(String prompt) {
    final pLower = prompt.toLowerCase();
    for (final item in knowledgeBase) {
      final titleMatch = item.title
          .toLowerCase()
          .split(' ')
          .any((w) => w.length > 3 && pLower.contains(w));
      final contentMatch = item.content
          .toLowerCase()
          .split(' ')
          .any((w) => w.length > 3 && pLower.contains(w));
      if (titleMatch || contentMatch) {
        return _applyToneStyle('${item.title}: ${item.content}');
      }
    }
    if (pLower.contains('buka') ||
        pLower.contains('jam') ||
        pLower.contains('jadwal')) {
      return _applyToneStyle(
          'Layanan kami beroperasi setiap hari dari jam 08.00 hingga 21.00 WIB.');
    }
    if (pLower.contains('promo') ||
        pLower.contains('diskon') ||
        pLower.contains('harga')) {
      return _applyToneStyle(
          'Saat ini ada promo diskon 10% untuk pembelian/pemesanan berikutnya!');
    }
    if (pLower.contains('kirim') ||
        pLower.contains('lokasi') ||
        pLower.contains('alamat')) {
      return _applyToneStyle(
          'Kami dapat melayani pengiriman langsung ke seluruh wilayah kota dan sekitar.');
    }
    return _applyToneStyle(
        'Terima kasih atas pertanyaannya! Tim $title siap membantu keperluan Anda.');
  }

  String _applyToneStyle(String text) {
    var result = text;
    if (_tone == 0) {
      result = 'Halo. $result Apakah ada hal lain yang perlu dikonfirmasi?';
    } else if (_tone == 1) {
      result = 'Halo kak! $result Ada yang bisa aku bantu lagi? 😊';
    } else if (_tone == 2) {
      result = '${text.split('.').first}.';
    } else if (_tone == 3 && customTone != null && customTone!.isNotEmpty) {
      result = '[Gaya Kustom: "$customTone"]: $result';
    }
    return result;
  }

  String reply(int q) {
    if (_tone == 3 && customTone != null && customTone!.isNotEmpty) {
      return '[Gaya Kustom: "$customTone"]: ${[
        'Buka hingga 21.00.',
        'Diskon 10% pembelian kedua.',
        'Bisa kirim ke mana saja.',
      ][q]}';
    }
    const formal = [
      'Toko kami buka hingga pukul 21.00.',
      'Saat ini tersedia diskon 10% untuk pembelian kedua.',
      'Pengiriman ke luar kota tersedia melalui kurir terpercaya.'
    ];
    const ramah = [
      'Toko kami buka sampai jam 9 malam ya!',
      'Ada dong kak! Diskon 10% buat pembelian kedua!',
      'Bisa banget kak, kami kirim ke seluruh kota!'
    ];
    const pendek = [
      'Buka sampai 21.00.',
      'Ada. Diskon 10% pembelian kedua.',
      'Bisa. Kirim ke luar kota.'
    ];
    return [formal, ramah, pendek][_tone.clamp(0, 2)][q];
  }
}
