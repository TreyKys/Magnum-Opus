import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/core/services/revenuecat_service.dart';

class SubscriptionState {
  final bool hasSubscription;
  final String tier;

  SubscriptionState({
    this.hasSubscription = false,
    this.tier = 'free',
  });

  SubscriptionState copyWith({
    bool? hasSubscription,
    String? tier,
  }) {
    return SubscriptionState(
      hasSubscription: hasSubscription ?? this.hasSubscription,
      tier: tier ?? this.tier,
    );
  }
}

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() {
    return SubscriptionState();
  }

  Future<void> checkSubscription() async {
    final hasSubscription = await RevenueCatService.hasActiveSubscription();
    state = state.copyWith(hasSubscription: hasSubscription);
  }

  void upgradeSubscription(String tier) {
    state = state.copyWith(hasSubscription: true, tier: tier);
  }

  void downgrade() {
    state = SubscriptionState();
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
  () => SubscriptionNotifier(),
);
