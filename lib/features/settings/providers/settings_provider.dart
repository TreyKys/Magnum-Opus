import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool enableHaptics;
  final bool showReadingTips;
  final double defaultZoomLevel;

  SettingsState({
    this.enableHaptics = true,
    this.showReadingTips = true,
    this.defaultZoomLevel = 1.0,
  });

  SettingsState copyWith({
    bool? enableHaptics,
    bool? showReadingTips,
    double? defaultZoomLevel,
  }) {
    return SettingsState(
      enableHaptics: enableHaptics ?? this.enableHaptics,
      showReadingTips: showReadingTips ?? this.showReadingTips,
      defaultZoomLevel: defaultZoomLevel ?? this.defaultZoomLevel,
    );
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(() => SettingsNotifier());

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _hapticsKey = 'settings_haptics';
  static const String _tipsKey = 'settings_reading_tips';
  static const String _zoomKey = 'settings_zoom_level';

  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    _init();
    return SettingsState(); // Defaults — overwritten once prefs load
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      enableHaptics: _prefs.getBool(_hapticsKey) ?? true,
      showReadingTips: _prefs.getBool(_tipsKey) ?? true,
      defaultZoomLevel: _prefs.getDouble(_zoomKey) ?? 1.0,
    );
  }

  void toggleHaptics(bool value) {
    if (value) HapticFeedback.lightImpact();
    _prefs.setBool(_hapticsKey, value);
    state = state.copyWith(enableHaptics: value);
  }

  void toggleReadingTips(bool value) {
    if (state.enableHaptics) HapticFeedback.lightImpact();
    _prefs.setBool(_tipsKey, value);
    state = state.copyWith(showReadingTips: value);
  }

  void setZoomLevel(double zoom) {
    if (state.enableHaptics) HapticFeedback.selectionClick();
    _prefs.setDouble(_zoomKey, zoom);
    state = state.copyWith(defaultZoomLevel: zoom);
  }
}
