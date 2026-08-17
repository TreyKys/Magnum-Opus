import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final energyProvider = NotifierProvider<EnergyNotifier, int>(() => EnergyNotifier());

class EnergyNotifier extends Notifier<int> {
  static const String _energyKey = 'user_energy_charges';
  static const String _lastResetKey = 'last_energy_reset_date';

  static const int _maxFreeEnergy = 5;

  /// Flat rate: every rewarded ad grants exactly this many queries — no
  /// exponential compounding. Public so ad UIs can state the reward without
  /// hardcoding a number that could drift from what is actually granted.
  static const int adReward = 2;

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

  /// Returns the single query taken for a request that failed before producing
  /// an answer. Charging for an outage the user did not cause is the same
  /// unfairness as billing an audio credit for a failed transcription.
  Future<void> refundOne() async {
    final newValue = state + 1;
    await _prefs.setInt(_energyKey, newValue);
    state = newValue;
  }

  /// Flat reward: 1 ad = 2 queries, always. No counters, no compounding.
  Future<void> refillEnergy() async {
    final newValue = state + adReward;
    await _prefs.setInt(_energyKey, newValue);
    state = newValue;
  }
}
