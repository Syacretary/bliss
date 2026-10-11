import 'dart:async';

enum Step {
  intro1,
  intro2,
  intro3, // kenalan
  qPurpose,
  qVolume,
  qTone,
  qBusiness,
  qProvider,
  preview, // personalisasi
  connectChoice,
  overlayPerm,
  pairing, // hubungkan
  batteryPerm,
  notifPerm, // izin
  success,
}

enum Phase { kenalan, personalisasi, hubungkan, izin }

Phase phaseOf(Step s) {
  switch (s) {
    case Step.intro1:
    case Step.intro2:
    case Step.intro3:
      return Phase.kenalan;
    case Step.qPurpose:
    case Step.qVolume:
    case Step.qTone:
    case Step.qBusiness:
    case Step.qProvider:
    case Step.preview:
      return Phase.personalisasi;
    case Step.connectChoice:
    case Step.overlayPerm:
    case Step.pairing:
      return Phase.hubungkan;
    default:
      return Phase.izin;
  }
}

enum Purpose { personal, community, customerService, other }

enum ConnectMethod { qr, pairCode }

class Answers {
  Answers();
  Purpose? purpose;
  String? purposeOther;
  int? volumeIndex; // 0..3
  String? tone;
  String? businessName;
  String? provider;
  ConnectMethod? method;

  bool get isCS => purpose == Purpose.customerService;
  bool get isCommunity => purpose == Purpose.community;

  Answers copy() => Answers()
    ..purpose = purpose
    ..purposeOther = purposeOther
    ..volumeIndex = volumeIndex
    ..tone = tone
    ..businessName = businessName
    ..provider = provider
    ..method = method;

  Map<String, Object?> toJson() => {
        'purpose': purpose?.name,
        'purposeOther': purposeOther,
        'volumeIndex': volumeIndex,
        'tone': tone,
        'businessName': businessName,
        'provider': provider,
        'method': method?.name,
      };

  Map<String, Object?> toBotProfile() => {
        'purpose': purpose?.name ?? 'other',
        if (purposeOther != null) 'purposeOther': purposeOther,
        if (volumeIndex != null) 'volumeIndex': volumeIndex,
        if (tone != null) 'tone': tone,
        if (businessName != null) 'businessName': businessName,
        if (provider != null) 'provider': provider,
      };

  factory Answers.fromJson(Map<String, Object?> json) => Answers()
    ..purpose = _enumByName(Purpose.values, json['purpose'])
    ..purposeOther = json['purposeOther'] as String?
    ..volumeIndex = json['volumeIndex'] as int?
    ..tone = json['tone'] as String?
    ..businessName = json['businessName'] as String?
    ..provider = json['provider'] as String?
    ..method = _enumByName(ConnectMethod.values, json['method']);

  /// Estimasi hemat waktu: ±45 detik per pesan, memakai titik tengah tiap rentang.
  String get savedTimeLabel {
    const mid = [5, 30, 75, 150];
    final minutes = (mid[volumeIndex ?? 0] * 0.75).round();
    if (minutes < 60) return '~$minutes menit/hari';
    final h = (minutes / 60).round();
    return '~$h jam/hari';
  }

  @override
  String toString() =>
      'purpose=$purpose, volume=$volumeIndex, tone=$tone, biz=$businessName, provider=$provider, method=$method';
}

T? _enumByName<T extends Enum>(List<T> values, Object? value) {
  if (value is! String) return null;
  for (final item in values) {
    if (item.name == value) return item;
  }
  return null;
}

class OnboardingResult {
  const OnboardingResult({required this.answers, required this.completedAt});
  final Answers answers;
  final DateTime completedAt;
}

class OnboardingDraft {
  const OnboardingDraft({required this.step, required this.answers});
  final Step step;
  final Answers answers;
  Map<String, Object?> toJson() =>
      {'step': step.name, 'answers': answers.toJson()};
}

abstract interface class OnboardingProgressStore {
  Future<void> save(OnboardingDraft draft);
  Future<void> clear();
}

class NoopOnboardingProgressStore implements OnboardingProgressStore {
  const NoopOnboardingProgressStore();
  @override
  Future<void> clear() async {}
  @override
  Future<void> save(OnboardingDraft draft) async {}
}

class OnboardingDependencies {
  const OnboardingDependencies(
      {required this.connector,
      this.progressStore = const NoopOnboardingProgressStore()});
  final WhatsAppConnector connector;
  final OnboardingProgressStore progressStore;
  factory OnboardingDependencies.demo() =>
      OnboardingDependencies(connector: FakeConnector());
}

/// Antarmuka koneksi WhatsApp. Ganti dengan implementasi nyata (service/native bridge).
abstract class WhatsAppConnector {
  Stream<String> get pairingUpdates;

  /// Mengembalikan data QR / kode pairing untuk ditampilkan.
  Future<String> start(ConnectMethod method,
      {String? phoneNumber, Map<String, Object?>? profile});

  /// Selesai saat WhatsApp berhasil tertaut.
  Future<void> waitUntilConnected();

  /// Nomor bot (format internasional tanpa +), dipakai untuk tombol "kirim pesan test".
  String get botNumber;
}

class FakeConnector implements WhatsAppConnector {
  Completer<void> _completer = Completer<void>();

  @override
  Stream<String> get pairingUpdates => const Stream<String>.empty();

  @override
  String get botNumber => '628123456789';

  @override
  Future<String> start(ConnectMethod method,
      {String? phoneNumber, Map<String, Object?>? profile}) async {
    _completer = Completer<void>();
    await Future.delayed(const Duration(milliseconds: 600));
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!_completer.isCompleted) _completer.complete();
    });
    return method == ConnectMethod.pairCode ? 'BLIS-2026' : 'bliss://pair/demo';
  }

  @override
  Future<void> waitUntilConnected() => _completer.future;
}
