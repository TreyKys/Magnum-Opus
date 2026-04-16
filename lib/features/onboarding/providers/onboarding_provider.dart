import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingState {
  final bool completed;
  final String persona;

  const OnboardingState({
    this.completed = false,
    this.persona = '',
  });

  OnboardingState copyWith({bool? completed, String? persona}) {
    return OnboardingState(
      completed: completed ?? this.completed,
      persona: persona ?? this.persona,
    );
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
        () => OnboardingNotifier());

class OnboardingNotifier extends Notifier<OnboardingState> {
  static const String _doneKey = 'onboarding_done';
  static const String _personaKey = 'user_persona';

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
    );
  }

  Future<void> complete(String persona) async {
    await _prefs.setBool(_doneKey, true);
    await _prefs.setString(_personaKey, persona);
    state = OnboardingState(completed: true, persona: persona);
  }

  /// For testing — resets onboarding so it shows again on next launch.
  Future<void> reset() async {
    await _prefs.setBool(_doneKey, false);
    await _prefs.setString(_personaKey, '');
    state = const OnboardingState();
  }
}
