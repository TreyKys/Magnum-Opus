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

  // ─── Live units — AdMob app ca-app-pub-6864344458492366~4158994594 ─────
  /// `Free_Tier_Rewd_Ad` — backs the "Watch Ad +2" energy refill.
  static const String _liveRewardedAndroid =
      'ca-app-pub-6864344458492366/2702442692';

  /// `Free_Tier_RewInt_Ad` — a rewarded *interstitial* unit that exists in
  /// the AdMob account but is NOT wired up: the app only ever loads
  /// [RewardedAd], never RewardedInterstitialAd. Recorded here so the ID
  /// isn't lost if we later add a second placement.
  static const String liveRewardedInterstitialAndroid =
      'ca-app-pub-6864344458492366/6346174231';

  // No iOS AdMob app exists yet — there is no ios/ project in this repo.
  // Falls back to the test unit so an iOS build cannot ship a wrong ID.
  static const String? _liveRewardedIos = null;

  static bool get _isIos => !kIsWeb && Platform.isIOS;

  static String get _testRewarded =>
      _isIos ? _testRewardedIos : _testRewardedAndroid;

  /// Rewarded unit backing the "Watch Ad +2" energy refill.
  static String get rewardedUnitId {
    if (kDebugMode) return _testRewarded;

    // Optional override, so a unit can be rotated without shipping code.
    final overrideKey =
        _isIos ? 'ADMOB_REWARDED_UNIT_IOS' : 'ADMOB_REWARDED_UNIT_ANDROID';
    String? override;
    try {
      override = dotenv.env[overrideKey];
    } catch (_) {
      // dotenv not loaded (e.g. a widget test) — ignore and use the default.
      override = null;
    }
    if (override != null && override.trim().isNotEmpty) return override.trim();

    final live = _isIos ? _liveRewardedIos : _liveRewardedAndroid;
    if (live == null || live.isEmpty) {
      debugPrint('AdConfig: no live rewarded unit for this platform — '
          'using a TEST unit. This build will not earn revenue.');
      return _testRewarded;
    }
    return live;
  }

  /// True when the ID actually in use is one of Google's samples. Handy for a
  /// pre-release smoke check: this must be false in a store build.
  static bool get isUsingTestUnits =>
      rewardedUnitId.startsWith('ca-app-pub-3940256099942544');
}
