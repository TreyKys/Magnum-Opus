import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:magnum_opus/core/services/revenuecat_service.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/settings/providers/energy_provider.dart';
import 'package:magnum_opus/features/subscription/providers/subscription_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Tries to show RevenueCat's remote paywall; if none is configured for the
/// 'pro' offering (a common cause of "the upgrade button does nothing"),
/// falls back to our built-in upgrade screen so the user always sees something.
Future<void> presentUpgradeFlow(BuildContext context) async {
  try {
    final result = await RevenueCatUI.presentPaywallIfNeeded('pro');
    if (result == PaywallResult.notPresented && context.mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const UpgradeScreen()));
    }
  } catch (_) {
    if (context.mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const UpgradeScreen()));
    }
  }
}

/// Shown when a free user hits their daily query limit. Offers a choice
/// between watching a Rewarded Interstitial for +2 queries (reusing the same
/// energy-refill reward as the opt-in Rewarded ad) or going straight to Pro.
/// Falls back to the upgrade flow if no interstitial is preloaded.
Future<void> presentQueryLimitFlow(
  BuildContext context,
  WidgetRef ref, {
  RewardedInterstitialAd? ad,
  VoidCallback? onAdConsumed,
}) async {
  if (ad == null) {
    await presentUpgradeFlow(context);
    return;
  }

  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text("You've hit today's free limit",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      content: const Text(
        'Watch a quick ad for 2 more queries today, or go Pro for unlimited access.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'upgrade'),
          child: const Text('Upgrade to Pro',
              style: TextStyle(color: AppTheme.accentBlueLight, fontWeight: FontWeight.w700)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, 'watch'),
          child: const Text('Watch Ad (+2 queries)'),
        ),
      ],
    ),
  );

  if (choice == 'upgrade') {
    if (!context.mounted) return;
    await presentUpgradeFlow(context);
  } else if (choice == 'watch') {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) => a.dispose(),
      onAdFailedToShowFullScreenContent: (a, _) => a.dispose(),
    );
    ad.show(onUserEarnedReward: (_, __) {
      ref.read(energyProvider.notifier).refillEnergy();
    });
    onAdConsumed?.call();
  }
}

final offeringsProvider = FutureProvider<Offerings?>((ref) async {
  try {
    return await RevenueCatService.getOfferings();
  } catch (e) {
    return null;
  }
});

class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  String? _purchasingId;

  @override
  Widget build(BuildContext context) {
    final offerings = ref.watch(offeringsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Upgrade',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: offerings.when(
        data: (data) {
          final pro = data?.getOffering('pro');

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                const SizedBox(height: 28),
                const _TierCard(
                  tier: 'Free',
                  price: 'Current plan',
                  isCurrent: true,
                  features: [
                    '5 AI queries per day',
                    '5 active chat sessions',
                    '3 audio document ingests',
                    'PDF, DOCX, PPTX, XLSX, EPUB',
                    'Gemini 2.5 Flash powered',
                  ],
                ),
                if (pro != null && pro.monthly != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _TierCard(
                      tier: 'Pro Monthly',
                      price: '${pro.monthly!.storeProduct.priceString} / month',
                      isCurrent: false,
                      isLoading: _purchasingId == pro.monthly!.identifier,
                      features: const [
                        'Unlimited AI queries',
                        'Unlimited chat sessions',
                        'Unlimited audio ingests',
                        'Priority response speed',
                        'All Free features included',
                      ],
                      onTap: _purchasingId == null
                          ? () => _purchase(context, pro.monthly!)
                          : null,
                    ),
                  ),
                if (pro != null && pro.annual != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _TierCard(
                      tier: 'Pro Annual',
                      price: '${pro.annual!.storeProduct.priceString} / year',
                      badge: 'BEST VALUE',
                      isCurrent: false,
                      isFeatured: true,
                      isLoading: _purchasingId == pro.annual!.identifier,
                      features: const [
                        'Unlimited AI queries',
                        'Unlimited chat sessions',
                        'Unlimited audio ingests',
                        'Priority response speed',
                        'All Free features included',
                        'Save vs. paying monthly',
                      ],
                      onTap: _purchasingId == null
                          ? () => _purchase(context, pro.annual!)
                          : null,
                    ),
                  ),
                const SizedBox(height: 28),
                const _Footer(),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Text(
            'Error fetching offerings: $e',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Future<void> _purchase(BuildContext context, Package package) async {
    setState(() => _purchasingId = package.identifier);
    try {
      final customerInfo = await RevenueCatService.purchasePackage(package);
      final isPro = customerInfo.entitlements.all['pro']?.isActive ?? false;
      if (isPro) {
        ref.read(subscriptionProvider.notifier).upgradeSubscription('pro');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome to Pro — unlimited access unlocked!')),
          );
          Navigator.pop(context);
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase did not complete. Please try again.')),
        );
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        // User cancelled — no need to show an error.
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_messageForErrorCode(code))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong with the purchase. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasingId = null);
    }
  }

  String _messageForErrorCode(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.networkError:
        return 'No internet connection. Please check your network and try again.';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device.';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'You already own this plan. Try restoring your purchases.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Your payment is pending approval. Pro will activate once it completes.';
      default:
        return 'Something went wrong with the purchase. Please try again.';
    }
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withAlpha(38),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bolt, color: AppTheme.accentBlue, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Unlock Your Full Potential',
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Upgrade for unlimited access to your AI document intelligence assistant.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  final String tier;
  final String price;
  final bool isCurrent;
  final bool isFeatured;
  final bool isLoading;
  final String? badge;
  final List<String> features;
  final VoidCallback? onTap;

  const _TierCard({
    required this.tier,
    required this.price,
    required this.isCurrent,
    required this.features,
    this.isFeatured = false,
    this.isLoading = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isCurrent
        ? AppTheme.border
        : isFeatured
            ? const Color(0xFFFFD700)
            : AppTheme.accentBlue;

    final badgeColor = isCurrent
        ? AppTheme.surfaceVariant
        : isFeatured
            ? const Color(0xFFFFD700).withAlpha(38)
            : AppTheme.accentBlue.withAlpha(31);

    final badgeTextColor = isCurrent
        ? AppTheme.textMuted
        : isFeatured
            ? const Color(0xFFFFD700)
            : AppTheme.accentBlueLight;

    final badgeLabel = isCurrent ? 'YOUR PLAN' : badge;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isCurrent || isFeatured ? 1.5 : 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      price,
                      style: TextStyle(
                          color: isCurrent ? AppTheme.textMuted : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (badgeLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                        color: badgeTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: isCurrent ? AppTheme.textMuted : AppTheme.accentBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                            color: isCurrent ? AppTheme.textMuted : Colors.white70,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
          if (!isCurrent) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFeatured ? const Color(0xFFFFD700) : AppTheme.accentBlue,
                  foregroundColor: isFeatured ? Colors.black : Colors.white,
                  disabledBackgroundColor:
                      (isFeatured ? const Color(0xFFFFD700) : AppTheme.accentBlue).withAlpha(140),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: isFeatured ? Colors.black : Colors.white,
                        ),
                      )
                    : const Text(
                        'Upgrade to Pro',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_outlined, color: AppTheme.accentBlueLight, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Powered by Gemini 2.5 Flash · All processing on-device',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
