import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState());

  void toggleHaptics(bool value) {
    if (value) HapticFeedback.lightImpact();
    state = state.copyWith(enableHaptics: value);
  }

  void toggleReadingTips(bool value) {
    if (state.enableHaptics) HapticFeedback.lightImpact();
    state = state.copyWith(showReadingTips: value);
  }

  void setZoomLevel(double zoom) {
    if (state.enableHaptics) HapticFeedback.selectionClick();
    state = state.copyWith(defaultZoomLevel: zoom);
  }
}
