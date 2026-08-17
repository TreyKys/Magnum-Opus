import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingState {
  final bool completed;
  final String persona;
  final String displayName;

  const OnboardingState({
    this.completed = false,
    this.persona = '',
    this.displayName = '',
  });

  OnboardingState copyWith({
    bool? completed,
    String? persona,
    String? displayName,
  }) {
    return OnboardingState(
      completed: completed ?? this.completed,
      persona: persona ?? this.persona,
      displayName: displayName ?? this.displayName,
    );
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
        () => OnboardingNotifier());

class OnboardingNotifier extends Notifier<OnboardingState> {
  static const String _doneKey = 'onboarding_done';
  static const String _personaKey = 'user_persona';
  static const String _nameKey = 'user_display_name';

  late SharedPreferences _prefs;

  @override
  OnboardingState build() {
    _init();
    return const OnboardingState();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    state = OnboardingState(
      completed: _prefs.getBool(_doneKey) ?? false,
      persona: _prefs.getString(_personaKey) ?? '',
      displayName: _prefs.getString(_nameKey) ?? '',
    );
  }

  Future<void> complete(String persona, {String displayName = ''}) async {
    await _prefs.setBool(_doneKey, true);
    await _prefs.setString(_personaKey, persona);
    await _prefs.setString(_nameKey, displayName.trim());
    state = OnboardingState(
      completed: true,
      persona: persona,
      displayName: displayName.trim(),
    );
  }

  Future<void> updateDisplayName(String name) async {
    await _prefs.setString(_nameKey, name.trim());
    state = state.copyWith(displayName: name.trim());
  }

  Future<void> reset() async {
    await _prefs.setBool(_doneKey, false);
    await _prefs.setString(_personaKey, '');
    state = const OnboardingState();
  }
}
