import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../dashboard/dashboard_repository.dart';
import 'models.dart';

/// Flutter adapter for the in-app Node.js service. All HTTP traffic is loopback-only
/// and protected by a process-local bearer token returned from the native channel.
class AndroidWhatsAppConnector
    implements WhatsAppConnector, DashboardRepository {
  static const _channel = MethodChannel('bliss/bot_runtime');
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3)
    ..idleTimeout = const Duration(seconds: 30);
  final StreamController<Map<String, Object?>> _events =
      StreamController<Map<String, Object?>>.broadcast();

  String? _token;
  int? _port;
  StreamSubscription<String>? _eventLines;
  Timer? _eventsReconnectTimer;
  Timer? _eventsWatchdog;
  DateTime? _lastEventsFrameAt;
  int _eventsReconnectAttempts = 0;
  bool _disposed = false;
  String _botNumber = '';

  @override
  String get botNumber => _botNumber;

  @override
  Stream<String> get pairingUpdates => _events.stream
      .where((event) => event['type'] == 'pairing')
      .map((event) => event['value'] as String);

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Future<void> connectEvents() async {
    await _ensureRuntime();
    await _openEvents();
  }

  @override
  Future<DashboardAnalytics> analytics({
    required int days,
    required int utcOffsetMinutes,
  }) async {
    final data = await _dashboardGet(
      '/v1/analytics?days=$days&utcOffsetMinutes=$utcOffsetMinutes',
    );
    return DashboardAnalytics.fromJson(data);
  }

  @override
  Future<List<DashboardConversation>> conversations({int limit = 100}) async {
    final data = await _dashboardGet('/v1/conversations?limit=$limit');
    final rows = data['conversations'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map((item) =>
            DashboardConversation.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<List<DashboardMessage>> messages(String conversationId,
      {int limit = 100}) async {
    final data = await _dashboardGet(
        '/v1/conversations/$conversationId/messages?limit=$limit');
    final rows = data['messages'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map((item) =>
            DashboardMessage.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<DashboardConnection> connection() async {
    final data = await _dashboardGet('/v1/status');
    final phone = data['botNumber'] as String?;
    if (phone != null && phone.isNotEmpty) _botNumber = phone;
    return DashboardConnection(
      status: data['status'] as String? ?? 'idle',
      phone: phone,
    );
  }

  @override
  Future<Map<String, Object?>> botConfiguration() =>
      _dashboardGet('/v1/config');

  @override
  Future<List<Map<String, Object?>>> pluginStore() async {
    final data = await _dashboardGet('/v1/plugin-store');
    final rows = data['plugins'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }

  @override
  Future<void> savePlugins(List<Map<String, Object?>> plugins) async {
    final response =
        await _request('PATCH', '/v1/plugins', body: {'plugins': plugins});
    final data = await _decodeResponse(response);
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(_dashboardError(data['error']));
    }
  }

  @override
  Future<Set<String>> configuredProviders() async {
    final data = await _dashboardGet('/v1/providers');
    final values = data['providers'];
    if (values is! List) return const {};
    return values
        .whereType<Map<String, dynamic>>()
        .where((provider) => provider['configured'] == true)
        .map((provider) => provider['id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> configureBot({
    required Map<String, Object?> configuration,
    required String providerId,
    String? apiKey,
  }) async {
    await _ensureRuntime();
    final cleanKey = apiKey?.trim() ?? '';
    if (cleanKey.isNotEmpty) {
      final response = await _request(
        'PUT',
        '/v1/providers/${Uri.encodeComponent(providerId)}/credential',
        body: {'apiKey': cleanKey},
      );
      final data = await _decodeResponse(response);
      if (response.statusCode != HttpStatus.ok) {
        throw StateError(_dashboardError(data['error']));
      }
    }
    final response = await _request('PATCH', '/v1/config', body: configuration);
    final data = await _decodeResponse(response);
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(_dashboardError(data['error']));
    }
  }

  @override
  Future<String> testReply(String message) async {
    final data = await _dashboardPostWithResponse(
      '/v1/test-reply',
      body: {'message': message},
    );
    return data['reply'] as String? ?? '';
  }

  @override
  Future<void> startBot() async {
    await _ensureRuntime();
    await _openEvents();
    final response = await _request('POST', '/v1/start',
        body: {
          'method': 'qr',
        },
        timeout: const Duration(seconds: 55));
    final data = await _decodeResponse(response);
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(_dashboardError(data['error']));
    }
    final pairing = data['pairing'];
    if (pairing is String && pairing.isNotEmpty && pairing != 'CONNECTED') {
      await _dashboardPost('/v1/stop');
      throw StateError(
          'Sesi WhatsApp perlu ditautkan ulang. Hubungkan kembali akun WhatsApp terlebih dahulu.');
    }
  }

  @override
  Future<void> stopBot() => _dashboardPost('/v1/stop');

  @override
  Future<void> setTakeover(String conversationId, bool enabled) async {
    await _dashboardPost(
      '/v1/conversations/$conversationId/${enabled ? 'takeover' : 'resume'}',
    );
  }

  @override
  Future<void> reply(String conversationId, String text) async {
    await _dashboardPost('/v1/conversations/$conversationId/reply',
        body: {'text': text});
  }

  Future<Map<String, dynamic>> _dashboardGet(String path) async {
    await _ensureRuntime();
    final response = await _request('GET', path);
    final data = await _decodeResponse(response);
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(_dashboardError(data['error']));
    }
    return data;
  }

  Future<void> _dashboardPost(String path, {Map<String, Object?>? body}) async {
    await _ensureRuntime();
    final response = await _request('POST', path, body: body);
    final data = await _decodeResponse(response);
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(_dashboardError(data['error']));
    }
  }

  Future<Map<String, dynamic>> _dashboardPostWithResponse(String path,
      {Map<String, Object?>? body}) async {
    await _ensureRuntime();
    final response = await _request('POST', path, body: body);
    final data = await _decodeResponse(response);
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(_dashboardError(data['error']));
    }
    return data;
  }

  String _dashboardError(Object? value) {
    switch (value) {
      case 'CONVERSATION_NOT_FOUND':
        return 'Percakapan sudah tidak tersedia.';
      case 'NOT_CONNECTED':
        return 'WhatsApp sedang tidak terhubung.';
      case 'CONVERSATION_STORE_UNAVAILABLE':
        return 'Penyimpanan percakapan belum tersedia.';
      case 'ALREADY_RUNNING':
        return 'Bot sedang aktif atau dalam proses menghubungkan.';
      case 'SESSION_LOGGED_OUT':
        return 'Sesi WhatsApp berakhir. Pilih tambah/tautkan nomor untuk memindai QR atau meminta kode pairing baru.';
      case 'RECONNECT_EXHAUSTED':
        return 'Koneksi WhatsApp gagal pulih. Periksa jaringan, lalu aktifkan bot untuk mencoba lagi.';
      case 'EXTERNAL_PROCESSING_CONSENT_REQUIRED':
        return 'Persetujuan pemrosesan AI eksternal belum diaktifkan.';
      case 'AI_PROVIDER_CREDENTIAL_MISSING':
        return 'API key untuk provider ini belum disimpan di Studio.';
      case 'AI_PROVIDER_HTTP_400':
      case 'AI_PROVIDER_HTTP_404':
      case 'AI_PROVIDER_HTTP_422':
        return 'Provider menolak model yang dipilih. Periksa ID model di Studio.';
      case 'AI_PROVIDER_HTTP_401':
      case 'AI_PROVIDER_HTTP_403':
        return 'API key ditolak provider. Periksa key dan akses model.';
      case 'AI_PROVIDER_HTTP_429':
        return 'Kuota atau batas request provider tercapai. Coba lagi nanti.';
      case 'AI_PROVIDER_REQUEST_FAILED':
      case 'AI_PROVIDER_RESPONSE_INVALID':
        return 'Provider tidak dapat dipanggil. Periksa koneksi internet dan pengaturan model.';
      case 'PROVIDER_CREDENTIAL_REQUIRED':
        return 'API key provider AI belum dikonfigurasi.';
      case 'PROVIDER_NOT_AVAILABLE':
        return 'Provider AI yang dipilih belum tersedia.';
      case 'FEATURES_DEFERRED':
        return 'Plugin dan perintah kustom belum aktif di runtime WhatsApp.';
      case 'INVALID_CREDENTIAL':
      case 'PROVIDER_CREDENTIAL_INVALID':
        return 'API key tidak valid. Periksa kembali key dari provider.';
      case 'INVALID_BODY':
        return 'Pengaturan belum valid. Periksa model dan konfigurasi Studio.';
      default:
        return 'Data bot lokal belum bisa dimuat. Coba lagi.';
    }
  }

  @override
  Future<String> start(ConnectMethod method,
      {String? phoneNumber, Map<String, Object?>? profile}) async {
    if (method == ConnectMethod.pairCode &&
        (phoneNumber == null || !RegExp(r'^\d{8,15}$').hasMatch(phoneNumber))) {
      throw const FormatException(
          'Gunakan nomor internasional berisi 8–15 digit tanpa tanda +.');
    }
    await _ensureRuntime();
    await _openEvents();
    final response = await _request('POST', '/v1/start', body: {
      'method': method == ConnectMethod.pairCode ? 'pairCode' : 'qr',
      'phoneNumber': phoneNumber,
      'profile': profile ?? const <String, Object?>{'purpose': 'other'},
    });
    final data = await _decodeResponse(response);
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(_friendlyError(data['error']));
    }
    return data['pairing'] as String? ?? 'CONNECTED';
  }

  @override
  Future<void> waitUntilConnected() async {
    final current = await _request('GET', '/v1/status');
    if (current.statusCode == HttpStatus.ok) {
      final data = await _decodeResponse(current);
      if (data['status'] == 'connected') {
        _botNumber = data['botNumber'] as String? ?? '';
        return;
      }
    }
    final completer = Completer<void>();
    late final StreamSubscription<Map<String, Object?>> subscription;
    subscription = _events.stream.listen((event) {
      if (event['type'] != 'status') return;
      final status = event['status'];
      if (status == 'connected' && !completer.isCompleted) {
        completer.complete();
      } else if ((status == 'loggedOut' || status == 'error') &&
          !completer.isCompleted) {
        completer.completeError(StateError('Koneksi WhatsApp terputus.'));
      }
    });
    try {
      // Close the gap between the first status request and subscribing to SSE.
      final latest = await _request('GET', '/v1/status');
      if (latest.statusCode == HttpStatus.ok) {
        final data = await _decodeResponse(latest);
        if (data['status'] == 'connected') {
          _botNumber = data['botNumber'] as String? ?? '';
          return;
        }
        if (data['status'] == 'loggedOut' || data['status'] == 'error') {
          throw StateError('Koneksi WhatsApp terputus.');
        }
      }
      await completer.future.timeout(const Duration(minutes: 3));
      final status = await _request('GET', '/v1/status');
      if (status.statusCode == HttpStatus.ok) {
        _botNumber =
            (await _decodeResponse(status))['botNumber'] as String? ?? '';
      }
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> stop({bool logout = false}) async {
    if (_token == null) return;
    final response = await _request('POST', logout ? '/v1/logout' : '/v1/stop');
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Tidak dapat menghentikan sesi Bliss.');
    }
  }

  Future<void> _ensureRuntime() async {
    if (_token == null || _port == null) {
      try {
        final result =
            await _channel.invokeMapMethod<String, Object?>('startRuntime');
        _token = result?['token'] as String?;
        _port = result?['port'] as int?;
      } catch (_) {
        throw StateError(
            'Layanan bot Android tidak dapat dimulai. Pastikan izin notifikasi tersedia, lalu buka kembali Bliss dan coba lagi.');
      }
    }
    if (_token == null || _port == null) {
      throw StateError(
          'Runtime Node.js Android tidak mengembalikan alamat lokal.');
    }
    Object? lastError;
    for (var attempt = 0; attempt < 40; attempt++) {
      try {
        final response = await _request('GET', '/v1/health');
        if (response.statusCode == HttpStatus.ok) {
          final health = await _decodeResponse(response);
          if (health['ready'] == true) {
            await _channel.invokeMethod<void>('markRuntimeReady');
            return;
          }
          lastError = StateError('Runtime belum menyatakan siap.');
        }
      } catch (error) {
        lastError = error;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final nativeState = await _channel.invokeMethod<String>('runtimeState');
    if (nativeState == 'failed' || nativeState == 'exited') {
      try {
        // The in-app foreground service can restart Node in-place after an
        // unexpected event-loop exit, without asking the user to restart Bliss.
        final restarted =
            await _channel.invokeMapMethod<String, Object?>('startRuntime');
        _token = restarted?['token'] as String? ?? _token;
        _port = restarted?['port'] as int? ?? _port;
        for (var attempt = 0; attempt < 40; attempt++) {
          try {
            final response = await _request('GET', '/v1/health');
            if (response.statusCode == HttpStatus.ok &&
                (await _decodeResponse(response))['ready'] == true) {
              await _channel.invokeMethod<void>('markRuntimeReady');
              return;
            }
          } catch (error) {
            lastError = error;
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError(
        'Runtime lokal tidak merespons. Buka kembali Bliss, pastikan notifikasi layanan bot aktif, izinkan aktivitas latar belakang, lalu coba lagi. ${lastError ?? ''}');
  }

  Future<void> _openEvents() async {
    if (_disposed) return;
    if (_eventLines != null) return;
    try {
      final request = await _client.getUrl(_uri('/v1/events'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('Tidak dapat membuka kanal status bot.');
      }
      _lastEventsFrameAt = DateTime.now();
      late final StreamSubscription<String> subscription;
      subscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _lastEventsFrameAt = DateTime.now();
        if (line.startsWith(':')) {
          _eventsReconnectAttempts = 0;
          if (!_events.isClosed) {
            _events.add({
              'type': 'heartbeat',
              'timestamp': _lastEventsFrameAt!.millisecondsSinceEpoch
            });
          }
          return;
        }
        if (!line.startsWith('data: ')) return;
        try {
          final value = jsonDecode(line.substring(6));
          if (value is Map<String, dynamic>) {
            _events.add(Map<String, Object?>.from(value));
          }
        } on FormatException {
          // Ignore malformed frames; watchdog reconnects if the stream stalls.
        }
      }, onError: (Object error, StackTrace stack) {
        _handleEventsDisconnect(subscription, error);
      }, onDone: () {
        _handleEventsDisconnect(
            subscription, StateError('Kanal status lokal terputus.'));
      });
      _eventLines = subscription;
      _eventsReconnectTimer?.cancel();
      _eventsReconnectTimer = null;
      _eventsWatchdog ??= Timer.periodic(const Duration(seconds: 20), (_) {
        final subscription = _eventLines;
        final lastFrame = _lastEventsFrameAt;
        if (subscription != null &&
            lastFrame != null &&
            DateTime.now().difference(lastFrame) >
                const Duration(seconds: 45)) {
          _handleEventsDisconnect(
              subscription, TimeoutException('Heartbeat runtime terhenti.'));
        }
      });
    } catch (error) {
      _scheduleEventsReconnect();
      rethrow;
    }
  }

  void _handleEventsDisconnect(
      StreamSubscription<String> subscription, Object error) {
    if (_disposed || !identical(_eventLines, subscription)) return;
    _eventLines = null;
    _lastEventsFrameAt = null;
    unawaited(subscription.cancel());
    if (!_events.isClosed) {
      _events.add({
        'type': 'transportError',
        'message':
            'Koneksi data runtime terputus; Bliss sedang mencoba menyambung ulang.',
      });
    }
    _scheduleEventsReconnect();
  }

  void _scheduleEventsReconnect() {
    if (_disposed || _eventsReconnectTimer != null) return;
    _eventsReconnectAttempts++;
    final exponent = (_eventsReconnectAttempts - 1).clamp(0, 5).toInt();
    final seconds = (1 << exponent).clamp(1, 30).toInt();
    _eventsReconnectTimer = Timer(Duration(seconds: seconds), () async {
      _eventsReconnectTimer = null;
      try {
        await _ensureRuntime();
        await _openEvents();
      } catch (_) {
        _scheduleEventsReconnect();
      }
    });
  }

  Future<HttpClientResponse> _request(String method, String path,
      {Map<String, Object?>? body,
      Duration timeout = const Duration(seconds: 8)}) async {
    final request = await _client.openUrl(method, _uri(path));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    return request.close().timeout(timeout);
  }

  Uri _uri(String path) {
    final parsed = Uri.parse(path);
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: _port!,
      path: parsed.path,
      query: parsed.hasQuery ? parsed.query : null,
    );
  }

  Future<Map<String, dynamic>> _decodeResponse(
      HttpClientResponse response) async {
    final decoded = jsonDecode(await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 8)));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respons runtime tidak valid.');
    }
    return decoded;
  }

  String _friendlyError(Object? value) {
    final message = value?.toString() ?? '';
    if (message.contains('INVALID_PHONE_NUMBER')) {
      return 'Nomor tidak valid. Gunakan kode negara dan angka saja.';
    }
    if (message.contains('ALREADY_RUNNING')) {
      return 'Sesi WhatsApp sudah berjalan.';
    }
    return 'Tidak dapat memulai koneksi WhatsApp. Coba lagi.';
  }

  void dispose() {
    _disposed = true;
    _eventsReconnectTimer?.cancel();
    _eventsWatchdog?.cancel();
    _eventLines?.cancel();
    _events.close();
    _client.close(force: true);
  }
}
