import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:magnum_opus/core/subscription/subscription_service.dart';

class SubscriptionState {
  final bool isPro;
  final bool isLoading;
  final Offerings? offerings;
  final String? error;

  const SubscriptionState({
    this.isPro = false,
    this.isLoading = true,
    this.offerings,
    this.error,
  });

  SubscriptionState copyWith({
    bool? isPro,
    bool? isLoading,
    Offerings? offerings,
    String? error,
    bool clearError = false,
  }) {
    return SubscriptionState(
      isPro: isPro ?? this.isPro,
      isLoading: isLoading ?? this.isLoading,
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
      state = state.copyWith(isLoading: false, isPro: false);
      return;
    }

    _listener = _onCustomerInfoUpdate;
    SubscriptionService.addCustomerInfoListener(_listener!);

    try {
      final info = await SubscriptionService.getCustomerInfo();
      final offerings = await SubscriptionService.getOfferings();
      state = state.copyWith(
        isLoading: false,
        isPro: info != null && SubscriptionService.hasProEntitlement(info),
        offerings: offerings,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
      state = state.copyWith(offerings: offerings);
    } catch (_) {}
  }

  /// Returns true if the purchase resulted in an active Pro entitlement.
  /// Returns false on cancellation or failure (error is set on state,
  /// except for user-cancelled purchases which fail silently).
  Future<bool> purchase(Package package) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final info = await SubscriptionService.purchasePackage(package);
      final isPro = SubscriptionService.hasProEntitlement(info);
      state = state.copyWith(isLoading: false, isPro: isPro);
      return isPro;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        state = state.copyWith(isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Purchase failed. Please try again.',
        );
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Purchase failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> restore() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final info = await SubscriptionService.restorePurchases();
      final isPro = SubscriptionService.hasProEntitlement(info);
      state = state.copyWith(isLoading: false, isPro: isPro);
      return isPro;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not restore purchases. Please try again.',
      );
      return false;
    }
  }
}
