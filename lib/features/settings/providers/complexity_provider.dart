import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final complexityProvider =
    NotifierProvider<ComplexityNotifier, int>(() => ComplexityNotifier());

class ComplexityNotifier extends Notifier<int> {
  static const String _key = 'complexity_level';

  late SharedPreferences _prefs;

  @override
  int build() {
    _init();
    return 50; // Default: Balanced — updated once prefs load
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    state = _prefs.getInt(_key) ?? 50;
  }

  Future<void> setComplexity(int value) async {
    final clamped = value.clamp(0, 100);
    await _prefs.setInt(_key, clamped);
    state = clamped;
  }
}

/// Returns a human-readable label for a 0–100 complexity value.
String complexityLabel(int value) {
  if (value <= 15) return 'ELI5';
  if (value <= 35) return 'Elementary';
  if (value <= 60) return 'Balanced';
  if (value <= 80) return 'Advanced';
  return 'PhD';
}
