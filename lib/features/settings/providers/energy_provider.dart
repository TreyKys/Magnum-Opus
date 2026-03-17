import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final energyProvider = NotifierProvider<EnergyNotifier, int>(() => EnergyNotifier());

class EnergyNotifier extends Notifier<int> {
  static const String _energyKey = 'user_energy_charges';
  static const String _lastResetKey = 'last_energy_reset_date';
  static const String _adsWatchedKey = 'ads_watched_count';

  static const int _maxFreeEnergy = 5;

  late SharedPreferences _prefs;

  @override
  int build() {
    _init();
    return 0; // Temporary before initialization
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();

    final lastResetStr = _prefs.getString(_lastResetKey);
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';

    if (lastResetStr != todayStr) {
      // New calendar day, reset energy and ad count
      await _prefs.setString(_lastResetKey, todayStr);
      await _prefs.setInt(_energyKey, _maxFreeEnergy);
      await _prefs.setInt(_adsWatchedKey, 0);
      state = _maxFreeEnergy;
    } else {
      // Same day, load existing energy
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

  Future<void> refillEnergy() async {
    int adsWatched = _prefs.getInt(_adsWatchedKey) ?? 0;

    // Exponential ratio: 2, 4, 8, 16...
    // adsWatched = 0 -> 2 energy
    // adsWatched = 1 -> 4 energy
    // adsWatched = 2 -> 8 energy
    int reward = 2 << adsWatched;

    await _prefs.setInt(_adsWatchedKey, adsWatched + 1);

    final newValue = state + reward;
    await _prefs.setInt(_energyKey, newValue);
    state = newValue;
  }
}
