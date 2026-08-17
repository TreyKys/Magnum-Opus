import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central source of AdMob unit IDs.
///
/// Debug builds ALWAYS serve Google's test units, regardless of what is
/// configured below. This is deliberate and must not be "optimised" away —
/// requesting live ads from a development build (and especially tapping
/// one) is invalid traffic, and AdMob suspends accounts for it.
///
/// Unit IDs are not secrets: they ship inside every APK and are trivially
/// recoverable from it, so they live in source rather than `.env`. An
/// optional `.env` override is still honoured in release builds so a unit
/// can be swapped without a code change.
class AdConfig {
  // ─── Google sample units (permanently valid, never bill) ───────────────
  // https://developers.google.com/admob/android/test-ads
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _testRewardedInterstitialAndroid =
      'ca-app-pub-3940256099942544/5354046379';
  static const String _testRewardedInterstitialIos =
      'ca-app-pub-3940256099942544/6978759866';

  // ─── Live units — AdMob app ca-app-pub-6864344458492366~4158994594 ─────
  /// `Free_Tier_Rewd_Ad` — backs the "Watch Ad +2" energy refill.
  static const String _liveRewardedAndroid =
      'ca-app-pub-6864344458492366/2702442692';

  /// `Free_Tier_RewInt_Ad` — rewarded interstitial offered on chat exit.
  static const String _liveRewardedInterstitialAndroid =
      'ca-app-pub-6864344458492366/6346174231';

  // No iOS AdMob app exists yet — there is no ios/ project in this repo.
  // Falls back to the test unit so an iOS build cannot ship a wrong ID.
  static const String? _liveRewardedIos = null;

  static bool get _isIos => !kIsWeb && Platform.isIOS;

  static String get _testRewarded =>
      _isIos ? _testRewardedIos : _testRewardedAndroid;

  /// Rewarded unit backing the "Watch Ad" energy refill button.
  static String get rewardedUnitId {
    if (kDebugMode) return _testRewarded;

    final override = _envOverride(
        _isIos ? 'ADMOB_REWARDED_UNIT_IOS' : 'ADMOB_REWARDED_UNIT_ANDROID');
    if (override != null) return override;

    final live = _isIos ? _liveRewardedIos : _liveRewardedAndroid;
    if (live == null || live.isEmpty) {
      debugPrint('AdConfig: no live rewarded unit for this platform — '
          'using a TEST unit. This build will not earn revenue.');
      return _testRewarded;
    }
    return live;
  }

  static String get _testRewardedInterstitial => _isIos
      ? _testRewardedInterstitialIos
      : _testRewardedInterstitialAndroid;

  /// Rewarded interstitial offered when leaving a chat. No iOS unit exists
  /// yet, so iOS falls back to the test unit rather than shipping a wrong ID.
  static String get rewardedInterstitialUnitId {
    if (kDebugMode || _isIos) return _testRewardedInterstitial;

    final override = _envOverride('ADMOB_REWARDED_INTERSTITIAL_ANDROID');
    if (override != null) return override;

    return _liveRewardedInterstitialAndroid;
  }

  /// Reads a `.env` override, or null when absent/blank/unavailable.
  static String? _envOverride(String key) {
    try {
      final v = dotenv.env[key];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    } catch (_) {
      // dotenv not loaded (e.g. a widget test) — treat as absent.
    }
    return null;
  }

  /// True when either ID in use is one of Google's samples. Handy for a
  /// pre-release smoke check: this must be false in a store build.
  static bool get isUsingTestUnits =>
      rewardedUnitId.startsWith('ca-app-pub-3940256099942544') ||
      rewardedInterstitialUnitId.startsWith('ca-app-pub-3940256099942544');
}
