import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Small persistence adapter for onboarding progress and the completed profile.
/// Sensitive WhatsApp/provider credentials are deliberately not stored here.
class SharedPreferencesOnboardingStore implements OnboardingProgressStore {
  const SharedPreferencesOnboardingStore();

  static const _draftKey = 'bliss.onboarding.draft.v1';
  static const _answersKey = 'bliss.onboarding.completed_answers.v1';
  static const _linkedPhoneKey = 'bliss.whatsapp.linked_phone.v1';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<void> save(OnboardingDraft draft) async {
    final preferences = await _preferences;
    await preferences.setString(_draftKey, jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clear() async {
    final preferences = await _preferences;
    await preferences.remove(_draftKey);
  }

  Future<OnboardingDraft?> readDraft() async {
    final raw = (await _preferences).getString(_draftKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final stepName = decoded['step'];
      final answersJson = decoded['answers'];
      if (stepName is! String || answersJson is! Map<String, dynamic>) {
        return null;
      }
      final step = Step.values.where((item) => item.name == stepName);
      if (step.isEmpty || step.single == Step.success) return null;
      return OnboardingDraft(
        step: step.single,
        answers: Answers.fromJson(Map<String, Object?>.from(answersJson)),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<Answers?> readCompletedAnswers() async {
    final raw = (await _preferences).getString(_answersKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return Answers.fromJson(Map<String, Object?>.from(decoded));
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<String?> readLinkedPhone() async =>
      (await _preferences).getString(_linkedPhoneKey);

  Future<void> markCompleted(Answers answers, {String? linkedPhone}) async {
    final preferences = await _preferences;
    await preferences.setString(_answersKey, jsonEncode(answers.toJson()));
    if (linkedPhone != null && linkedPhone.isNotEmpty) {
      await preferences.setString(_linkedPhoneKey, linkedPhone);
    }
    await preferences.remove(_draftKey);
  }

  Future<void> reset() async {
    final preferences = await _preferences;
    await preferences.remove(_draftKey);
    await preferences.remove(_answersKey);
    await preferences.remove(_linkedPhoneKey);
  }
}
