import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:magnum_opus/core/subscription/subscription_service.dart';

class SubscriptionState {
  final bool isPro;

  /// A purchase or restore round-trip is in flight. This — and only this —
  /// disables the buy buttons.
  ///
  /// Deliberately separate from [isInitializing]: a single shared "loading"
  /// flag meant a slow or hung startup fetch left the buy button permanently
  /// stuck on "Processing…", which is exactly the bug this split fixes.
  final bool isBusy;

  /// The first entitlement/offerings fetch has not settled yet. Informational
  /// only — it must never gate purchasing, because offerings can arrive from
  /// [SubscriptionNotifier.refreshOfferings] independently of this flag.
  final bool isInitializing;

  final Offerings? offerings;
  final String? error;

  const SubscriptionState({
    this.isPro = false,
    this.isBusy = false,
    this.isInitializing = true,
    this.offerings,
    this.error,
  });

  SubscriptionState copyWith({
    bool? isPro,
    bool? isBusy,
    bool? isInitializing,
    Offerings? offerings,
    String? error,
    bool clearError = false,
  }) {
    return SubscriptionState(
      isPro: isPro ?? this.isPro,
      isBusy: isBusy ?? this.isBusy,
      isInitializing: isInitializing ?? this.isInitializing,
      offerings: offerings ?? this.offerings,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
        () => SubscriptionNotifier());

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  void Function(CustomerInfo)? _listener;

  @override
  SubscriptionState build() {
    ref.keepAlive();
    _init();
    ref.onDispose(() {
      if (_listener != null) {
        SubscriptionService.removeCustomerInfoListener(_listener!);
      }
    });
    return const SubscriptionState();
  }

  Future<void> _init() async {
    if (!SubscriptionService.isConfigured) {
      // RevenueCat API key not set — app runs on the free tier.
      state = state.copyWith(isInitializing: false, isPro: false);
      return;
    }

    _listener = _onCustomerInfoUpdate;
    SubscriptionService.addCustomerInfoListener(_listener!);

    try {
      // Fetched together rather than in sequence: entitlement state and
      // offerings are independent, and serialising them meant a slow
      // getCustomerInfo() also delayed the price. Both calls time out
      // internally, so this always settles.
      final results = await Future.wait([
        SubscriptionService.getCustomerInfo(),
        SubscriptionService.getOfferings(),
      ]);

      final info = results[0] as CustomerInfo?;
      final offerings = results[1] as Offerings?;

      state = state.copyWith(
        isInitializing: false,
        isPro: info != null && SubscriptionService.hasProEntitlement(info),
        offerings: offerings,
      );
    } catch (e) {
      // Never leave the UI initialising — the buy button does not depend on
      // this flag, but the spinner does.
      state = state.copyWith(isInitializing: false);
    }
  }

  void _onCustomerInfoUpdate(CustomerInfo info) {
    state = state.copyWith(
      isPro: SubscriptionService.hasProEntitlement(info),
    );
  }

  Future<void> refreshOfferings() async {
    try {
      final offerings = await SubscriptionService.getOfferings();
      if (offerings != null) {
        state = state.copyWith(offerings: offerings, isInitializing: false);
      }
    } catch (_) {}
  }

  /// Returns true if the purchase resulted in an active Pro entitlement.
  /// Returns false on cancellation or failure; [SubscriptionState.error] is
  /// set for real failures but left null when the user simply cancelled.
  Future<bool> purchase(Package package) async {
    if (state.isBusy) return false; // ignore double taps
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final info = await SubscriptionService.purchasePackage(package);
      final isPro = SubscriptionService.hasProEntitlement(info);
      state = state.copyWith(isBusy: false, isPro: isPro);
      return isPro;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        state = state.copyWith(isBusy: false);
      } else {
        state = state.copyWith(isBusy: false, error: _messageFor(code));
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: 'Purchase failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> restore() async {
    if (state.isBusy) return false;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final info = await SubscriptionService.restorePurchases();
      final isPro = SubscriptionService.hasProEntitlement(info);
      state = state.copyWith(isBusy: false, isPro: isPro);
      return isPro;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: 'Could not restore purchases. Please try again.',
      );
      return false;
    }
  }

  /// Store-billing failures are opaque by default; these map the codes users
  /// realistically hit to something they can act on.
  String _messageFor(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device or account.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Payment is pending approval. Pro unlocks once it clears.';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'You already own this — try Restore Purchases.';
      case PurchasesErrorCode.storeProblemError:
        return 'The Play Store had a problem. Please try again shortly.';
      case PurchasesErrorCode.networkError:
        return 'No connection to the store. Check your network and retry.';
      case PurchasesErrorCode.purchaseInvalidError:
        return 'This purchase was rejected by the store. Check your payment method.';
      default:
        return 'Purchase failed. Please try again.';
    }
  }
}
