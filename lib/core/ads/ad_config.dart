import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central source of AdMob unit IDs.
///
/// Debug builds ALWAYS serve Google's test units, regardless of what is
/// configured. This is deliberate and must not be "optimised" away —
/// requesting live ads from a development build (and especially tapping
/// one) is invalid traffic, and AdMob suspends accounts for it.
///
/// Release builds read the live unit from `.env`. If the key is missing the
/// app falls back to the test unit rather than passing an empty string to
/// the SDK: showing a test ad is a visible, harmless failure, whereas an
/// invalid unit ID just fails to load with no obvious cause.
class AdConfig {
  // Google's official, permanently-valid sample units.
  // https://developers.google.com/admob/android/test-ads
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';

  static String get _testRewarded {
    if (kIsWeb) return _testRewardedAndroid;
    return Platform.isIOS ? _testRewardedIos : _testRewardedAndroid;
  }

  /// Rewarded unit backing the "Watch Ad +2" energy refill.
  static String get rewardedUnitId {
    if (kDebugMode) return _testRewarded;

    final key = (!kIsWeb && Platform.isIOS)
        ? 'ADMOB_REWARDED_UNIT_IOS'
        : 'ADMOB_REWARDED_UNIT_ANDROID';

    String? live;
    try {
      live = dotenv.env[key];
    } catch (_) {
      // dotenv not loaded (e.g. a widget test) — fall through to test unit.
      live = null;
    }

    if (live == null || live.trim().isEmpty) {
      debugPrint(
          'AdConfig: $key missing from .env — falling back to a TEST ad unit. '
          'Release builds will not earn revenue until this is set.');
      return _testRewarded;
    }
    return live.trim();
  }

  /// True when the ID actually in use is one of Google's samples. Useful for
  /// asserting in a pre-release smoke check.
  static bool get isUsingTestUnits =>
      rewardedUnitId.startsWith('ca-app-pub-3940256099942544');
}
