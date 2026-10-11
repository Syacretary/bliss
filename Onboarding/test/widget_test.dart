// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bliss/dashboard/dashboard_repository.dart';
import 'package:bliss/dashboard/dashboard_shell.dart';
import 'package:bliss/dashboard/dash_state.dart';
import 'package:bliss/onboarding/models.dart' hide Step;
import 'package:bliss/onboarding/models.dart' show Step;
import 'package:bliss/onboarding/onboarding_store.dart';
import 'package:bliss/onboarding/screens_setup.dart';
import 'package:bliss/main.dart';

void main() {
  testWidgets('onboarding starts from the welcome screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BlissApp(connector: FakeConnector()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Lanjut'), findsOneWidget);
  });

  testWidgets('first-win dashboard action calls the app handoff',
      (tester) async {
    var openedDashboard = false;
    await tester.pumpWidget(MaterialApp(
      home: SuccessScreen(
        connector: FakeConnector(),
        onDone: () => openedDashboard = true,
      ),
    ));

    await tester.tap(find.text('Ke dashboard'));
    expect(openedDashboard, isTrue);
  });

  test('completed onboarding profile persists and clears its draft', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesOnboardingStore();
    final answers = Answers()
      ..purpose = Purpose.customerService
      ..businessName = 'Kedai Bliss';

    await store.save(OnboardingDraft(step: Step.qPurpose, answers: answers));
    expect((await store.readDraft())?.step, Step.qPurpose);

    await store.markCompleted(answers, linkedPhone: '628123456789');
    expect(await store.readDraft(), isNull);
    expect((await store.readCompletedAnswers())?.businessName, 'Kedai Bliss');
    expect(await store.readLinkedPhone(), '628123456789');
  });

  testWidgets('pairing advances only after connector confirms linked',
      (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final connector = _ControlledConnector();
    var advanced = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PairingScreen(
          answers: Answers()..method = ConnectMethod.qr,
          connector: connector,
          onNext: () => advanced = true,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Scan QR ini dari WhatsApp'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(advanced, isFalse);
    expect(find.text('Verifikasi & Lanjutkan'), findsNothing);

    connector.connected.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));
    expect(advanced, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating console button opens live console and returns to chats',
      (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = DashState(developerMockMode: true);
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: DashboardShell(state: state)));
    await tester.pump(const Duration(milliseconds: 400));

    final consoleButton = find.text('>_');
    expect(consoleButton, findsNothing);
    await tester.tap(find.byIcon(Icons.forum_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(consoleButton, findsOneWidget);
    await tester.tap(consoleButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.text('Console bot'), findsOneWidget);
    expect(find.textContaining('BLISS RUNTIME'), findsOneWidget);
    expect(find.textContaining('MOCK'), findsOneWidget);

    await tester.tap(find.text('>_'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.text('Percakapan'), findsWidgets);
  });

  test('dashboard bot switch calls local runtime start and stop', () async {
    final repository = _DashboardRepositoryFake();
    final state = DashState(repository: repository);
    addTearDown(state.dispose);
    addTearDown(repository.dispose);

    await state.toggleBot(true);
    expect(repository.startCalls, 1);
    expect(state.botOn, isTrue);

    await state.toggleBot(false);
    expect(repository.stopCalls, 1);
    expect(state.botOn, isFalse);
  });

  testWidgets('studio plugin flow stays stable on a compact screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _DashboardRepositoryFake()
      ..pluginStoreValue = [
        {
          'id': 'autotyping',
          'name': 'Auto-Typing Indicator',
          'description': 'Status mengetik saat Bliss menyusun balasan.',
          'permissions': ['whatsapp.presence'],
          'settingsSchema': [
            {
              'key': 'showWhileGenerating',
              'label': 'Tampilkan status mengetik',
              'type': 'boolean',
              'defaultValue': true,
            }
          ],
          'installed': false,
          'enabled': false,
          'settings': <String, Object?>{},
        }
      ];
    final state = DashState(repository: repository);
    addTearDown(state.dispose);
    addTearDown(repository.dispose);
    await state.refresh();
    await tester.pumpWidget(MaterialApp(home: DashboardShell(state: state)));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Studio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final configError = tester.takeException();
    if (configError != null) debugPrint('$configError');
    expect(configError, isNull);

    await tester.scrollUntilVisible(find.text('+ Plugin Store'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('+ Plugin Store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Plugin Store'));
    await tester.pumpAndSettle();
    expect(find.text('Plugin Store'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Pilih'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(find.text('Atur Auto-Typing Indicator'), findsOneWidget);
    await tester.tap(find.text('Simpan konfigurasi'));
    await tester.pumpAndSettle();
    expect(repository.savedPlugins.single['enabled'], false);
  });

  test('runtime diagnostic events appear in the live console', () async {
    final repository = _DashboardRepositoryFake();
    final state = DashState(repository: repository);
    addTearDown(state.dispose);
    addTearDown(repository.dispose);

    await state.refresh();
    repository.emit({
      'type': 'log',
      'level': 'INFO',
      'message': 'Kredensial API tersedia; nilai disembunyikan.',
    });
    await Future<void>.delayed(Duration.zero);

    expect(state.consoleLines.single.level, 'INFO');
    expect(state.consoleLines.single.message, contains('nilai disembunyikan'));
  });

  test('studio runtime config uses canonical Gemini model ID and consent state',
      () {
    final state = DashState();
    addTearDown(state.dispose);
    final config = state.runtimeConfiguration();
    expect(config['schemaVersion'], 2);
    expect((config['provider'] as Map<String, Object?>)['model'],
        'gemini-3.1-flash-lite');
    expect(
        (config['privacy'] as Map<String, Object?>)['allowExternalProcessing'],
        isFalse);
    expect(state.getModelIdForProvider('Google / Gemini'),
        'gemini-3.1-flash-lite');
    state.setModelForProvider('Google / Gemini', 'Gemini 3.1 Flash-Lite');
    expect(state.getModelIdForProvider('Google / Gemini'),
        'gemini-3.1-flash-lite');
  });

  test('live AI test does not silently fall back before external consent',
      () async {
    final state = DashState();
    addTearDown(state.dispose);
    final reply = await state.generateAiResponse('Halo');
    expect(reply, contains('persetujuan pemrosesan AI eksternal'));
    expect(reply, isNot(contains('Catatan API')));
  });

  test(
      'dashboard restores persisted provider and credential state without secrets',
      () async {
    final repository = _DashboardRepositoryFake()
      ..configurationValue = {
        'provider': {'id': 'gemini', 'model': 'gemini-3.1-flash-lite'},
        'style': {
          'preset': 'concise',
          'customText': '',
          'emojiLevel': .2,
          'responseLength': .3,
        },
        'privacy': {'allowExternalProcessing': true},
      }
      ..configuredProviderIds = {'gemini'};
    final state = DashState(repository: repository);
    addTearDown(state.dispose);
    addTearDown(repository.dispose);

    await state.refresh();
    expect(state.provider, 'Google / Gemini');
    expect(
        state.getModelIdForProvider(state.provider), 'gemini-3.1-flash-lite');
    expect(state.providerCredentialConfigured, isTrue);
    expect(state.providerConfigurationSaved, isTrue);
    expect(state.allowExternalProcessing, isTrue);
  });
}

class _ControlledConnector implements WhatsAppConnector {
  final connected = Completer<void>();

  @override
  Stream<String> get pairingUpdates => const Stream<String>.empty();

  @override
  String get botNumber => '628123456789';

  @override
  Future<String> start(ConnectMethod method,
          {String? phoneNumber, Map<String, Object?>? profile}) async =>
      'QR-PAYLOAD';

  @override
  Future<void> waitUntilConnected() => connected.future;
}

class _DashboardRepositoryFake implements DashboardRepository {
  final _events = StreamController<Map<String, Object?>>.broadcast();
  bool _connected = false;
  int startCalls = 0;
  int stopCalls = 0;
  Map<String, Object?> configurationValue = const {};
  Set<String> configuredProviderIds = const {};
  List<Map<String, Object?>> pluginStoreValue = const [];
  List<Map<String, Object?>> savedPlugins = const [];

  void emit(Map<String, Object?> event) => _events.add(event);

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Future<void> connectEvents() async {}

  @override
  Future<DashboardAnalytics> analytics(
          {required int days, required int utcOffsetMinutes}) async =>
      DashboardAnalytics(
        loggingEnabled: true,
        incomingMessages: 0,
        botReplies: 0,
        humanReplies: 0,
        activeConversations: 0,
        needsHuman: 0,
        responseCount: 0,
        averageResponseMs: 0,
        estimatedMinutesSaved: 0,
        hourlyIncoming: List.filled(24, 0),
        hourlyBotReplies: List.filled(24, 0),
        hourlyActiveConversations: List.filled(24, 0),
        daily: const [],
        topics: const [],
      );

  @override
  Future<List<DashboardConversation>> conversations({int limit = 100}) async =>
      const [];

  @override
  Future<DashboardConnection> connection() async =>
      DashboardConnection(status: _connected ? 'connected' : 'stopped');

  @override
  Future<Map<String, Object?>> botConfiguration() async => configurationValue;

  @override
  Future<List<Map<String, Object?>>> pluginStore() async => pluginStoreValue;

  @override
  Future<void> savePlugins(List<Map<String, Object?>> plugins) async {
    savedPlugins = plugins;
  }

  @override
  Future<Set<String>> configuredProviders() async => configuredProviderIds;

  @override
  Future<void> configureBot({
    required Map<String, Object?> configuration,
    required String providerId,
    String? apiKey,
  }) async {}

  @override
  Future<String> testReply(String message) async => 'Reply: $message';

  @override
  Future<List<DashboardMessage>> messages(String conversationId,
          {int limit = 100}) async =>
      const [];

  @override
  Future<void> reply(String conversationId, String text) async {}

  @override
  Future<void> setTakeover(String conversationId, bool enabled) async {}

  @override
  Future<void> startBot() async {
    startCalls++;
    _connected = true;
  }

  @override
  Future<void> stopBot() async {
    stopCalls++;
    _connected = false;
  }

  Future<void> dispose() => _events.close();
}
