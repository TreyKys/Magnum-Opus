import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final energyProvider = NotifierProvider<EnergyNotifier, int>(() => EnergyNotifier());

class EnergyNotifier extends Notifier<int> {
  static const String _energyKey = 'user_energy_charges';
  static const String _lastResetKey = 'last_energy_reset_date';

  static const int _maxFreeEnergy = 5;
  // Flat rate: every rewarded ad grants exactly 2 queries — no exponential compounding.
  static const int _adReward = 2;

  late SharedPreferences _prefs;

  @override
  int build() {
    _init();
    return 0; // Temporary before async init
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();

    final lastResetStr = _prefs.getString(_lastResetKey);
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';

    if (lastResetStr != todayStr) {
      // New calendar day — reset to free allocation
      await _prefs.setString(_lastResetKey, todayStr);
      await _prefs.setInt(_energyKey, _maxFreeEnergy);
      state = _maxFreeEnergy;
    } else {
      state = _prefs.getInt(_energyKey) ?? _maxFreeEnergy;
    }
  }

  Future<void> consumeEnergy() async {
    if (state > 0) {
      final newValue = state - 1;
      await _prefs.setInt(_energyKey, newValue);
      state = newValue;
    }
  }

  /// Flat reward: 1 ad = 2 queries, always. No counters, no compounding.
  Future<void> refillEnergy() async {
    final newValue = state + _adReward;
    await _prefs.setInt(_energyKey, newValue);
    state = newValue;
  }
}
