import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:magnum_opus/core/ads/ad_config.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/settings/providers/energy_provider.dart';

/// Second ad placement: a rewarded interstitial offered when the user leaves a
/// chat, granting bonus queries.
///
/// This differs fundamentally from the "Watch Ad" button. That one the user
/// taps deliberately; this one arrives at a moment they did not ask for. Google
/// therefore requires an intro screen announcing the reward with a clear way to
/// decline — [_confirm] is that screen, and it must not be removed.
///
/// The guardrails below exist so this never becomes the reason someone
/// uninstalls the app:
///
///  * Pro subscribers never see it.
///  * Only after a real exchange, so peeking into a chat is never punished.
///  * Persisted frequency cap, so relaunching cannot farm ads.
///  * It never blocks navigation — the caller pops regardless of outcome, and
///    every failure path here is swallowed rather than thrown.
class RewardedInterstitialController {
  RewardedInterstitialController._();
  static final RewardedInterstitialController instance =
      RewardedInterstitialController._();

  static const String _lastShownKey = 'rewint_last_shown_epoch_ms';

  /// Minimum gap between offers. Deliberately generous: this placement is
  /// opportunistic revenue, not the primary loop.
  static const Duration minInterval = Duration(minutes: 6);

  RewardedInterstitialAd? _ad;
  bool _loading = false;

  /// Warms the cache so the offer can appear without a visible delay.
  /// Safe to call repeatedly; no-ops when already loaded or in flight.
  void preload() {
    if (_ad != null || _loading) return;
    _loading = true;
    RewardedInterstitialAd.load(
      adUnitId: AdConfig.rewardedInterstitialUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (_) {
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }

  Future<bool> _inCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastShownKey);
      if (last == null) return false;
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - last;
      // Negative elapsed means the device clock moved backwards; treat that as
      // in-cooldown so a clock change can't be used to bypass the cap.
      if (elapsedMs < 0) return true;
      return elapsedMs < minInterval.inMilliseconds;
    } catch (_) {
      // Fail closed: no ad is strictly better than accidentally spamming one.
      return true;
    }
  }

  Future<void> _stampShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastShownKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Offers the ad if every guardrail passes, then resolves once the ad has
  /// been dismissed. Resolves immediately when the offer is skipped.
  ///
  /// [energy] and [isPro] are passed in rather than read from a `Ref` here,
  /// because the calling screen is mid-teardown and its ref may be disposed by
  /// the time the reward callback fires.
  ///
  /// Never throws.
  Future<void> maybeShowOnExit({
    required BuildContext context,
    required EnergyNotifier energy,
    required bool isPro,
    required bool hadConversation,
  }) async {
    try {
      if (isPro || !hadConversation) return;

      final ad = _ad;
      if (ad == null) {
        preload(); // nothing cached — warm it for next time
        return;
      }
      if (await _inCooldown()) return;
      if (!context.mounted) return;

      final accepted = await _confirm(context);
      if (accepted != true || !context.mounted) return;

      // Stamp before showing: a user who accepts has consumed the offer even
      // if the ad itself then fails, which prevents retry loops.
      await _stampShown();
      _ad = null;

      final dismissed = Completer<void>();
      void finish(RewardedInterstitialAd a) {
        a.dispose();
        if (!dismissed.isCompleted) dismissed.complete();
        preload(); // get the next one ready
      }

      ad.fullScreenContentCallback =
          FullScreenContentCallback<RewardedInterstitialAd>(
        onAdDismissedFullScreenContent: finish,
        onAdFailedToShowFullScreenContent: (a, _) => finish(a),
      );

      await ad.show(
        onUserEarnedReward: (_, __) => energy.refillEnergy(),
      );

      // Don't hang navigation forever if the SDK never reports dismissal.
      await dismissed.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {},
      );
    } catch (_) {
      // An ad must never obstruct leaving a screen.
    }
  }

  /// Intro screen. Required by AdMob policy for this format: it announces the
  /// reward and lets the user decline before any ad loads on screen.
  Future<bool?> _confirm(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Earn bonus queries'),
        content: Text(
          'Watch a short ad to add ${EnergyNotifier.adReward} queries to '
          'today\'s allowance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No thanks',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Watch · +${EnergyNotifier.adReward}'),
          ),
        ],
      ),
    );
  }
}
