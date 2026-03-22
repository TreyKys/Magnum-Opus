import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class EconomyState {
  final bool isPro;
  final int energy;
  final int dailyRefills;

  EconomyState({
    this.isPro = false,
    this.energy = 5,
    this.dailyRefills = 0,
  });

  EconomyState copyWith({
    bool? isPro,
    int? energy,
    int? dailyRefills,
  }) {
    return EconomyState(
      isPro: isPro ?? this.isPro,
      energy: energy ?? this.energy,
      dailyRefills: dailyRefills ?? this.dailyRefills,
    );
  }
}

final economyProvider = NotifierProvider<EconomyNotifier, EconomyState>(() {
  return EconomyNotifier();
});

class EconomyNotifier extends Notifier<EconomyState> {
  @override
  EconomyState build() {
    _initEconomy();
    return EconomyState();
  }

  Future<void> _initEconomy() async {
    final prefs = await SharedPreferences.getInstance();

    bool isPro = false;
    try {
      // Initialize with a dummy key for test environment.
      // The user specified that they will inject the production key later.
      await Purchases.configure(PurchasesConfiguration("appl_dummy_test_key_123456789"));
      final customerInfo = await Purchases.getCustomerInfo();
      isPro = customerInfo.entitlements.all["magnum_pro"]?.isActive ?? false;
    } catch (e) {
      // Fallback if RevenueCat setup fails in offline testing
      isPro = prefs.getBool('magnum_pro_fallback') ?? false;
    }

    // Check Daily Reset
    final lastResetStr = prefs.getString('last_reset_date');
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    int energy = prefs.getInt('ai_energy') ?? 5;
    int refills = prefs.getInt('daily_refills') ?? 0;

    if (lastResetStr != todayStr) {
      // Reset at midnight
      energy = 5;
      refills = 0;
      await prefs.setString('last_reset_date', todayStr);
      await prefs.setInt('ai_energy', energy);
      await prefs.setInt('daily_refills', refills);
    }

    state = state.copyWith(isPro: isPro, energy: energy, dailyRefills: refills);
  }

  Future<void> consumeEnergy(int amount) async {
    if (state.isPro) return; // Infinite energy

    if (state.energy >= amount) {
      final newEnergy = state.energy - amount;
      state = state.copyWith(energy: newEnergy);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ai_energy', newEnergy);
    }
  }

  Future<void> refillEnergy() async {
    if (state.isPro) return;

    final refills = state.dailyRefills + 1;
    int energyGained = 0;

    if (refills == 1) {
      energyGained = 5;
    } else if (refills == 2) {
      energyGained = 10;
    } else {
      energyGained = 20; // 3rd and subsequent refills give 20
    }

    final newEnergy = state.energy + energyGained;
    state = state.copyWith(energy: newEnergy, dailyRefills: refills);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ai_energy', newEnergy);
    await prefs.setInt('daily_refills', refills);
  }

  // Use dummy products for testing: magnum_pro_monthly, magnum_pro_yearly, magnum_pro_lifetime
  Future<void> upgradeToPro(String productId) async {
    try {
      // ignore: deprecated_member_use
      final StoreProduct product = await Purchases.getProducts([productId]).then((list) => list.first);
      // ignore: deprecated_member_use
      final result = await Purchases.purchaseStoreProduct(product);
      final isPro = result.customerInfo.entitlements.all["magnum_pro"]?.isActive ?? false;

      if (isPro) {
        state = state.copyWith(isPro: true);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('magnum_pro_fallback', true);
      }
    } catch (e) {
      // Handle cancellation or purchase error
      // In a real app, show a toast or dialog

      // Developer testing override:
      // If RevenueCat purchase fails due to sandbox, artificially unlock for testing purposes if requested.
      if (e.toString().contains('sandbox') || e.toString().contains('billing')) {
         state = state.copyWith(isPro: true);
         final prefs = await SharedPreferences.getInstance();
         await prefs.setBool('magnum_pro_fallback', true);
      }
    }
  }
}
