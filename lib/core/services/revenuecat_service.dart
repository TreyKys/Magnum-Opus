import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static Future<void> initialize() async {
    await Purchases.configure(PurchasesConfiguration('appl_mgemGPGrhxzVpHINyGdJscsynlS'));
  }

  /// Check if user has active subscription
  static Future<bool> hasActiveSubscription() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get customer info
  static Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      return null;
    }
  }

  /// Purchase a package
  static Future<CustomerInfo?> purchasePackage(Package package) async {
    try {
      PurchaseResult purchaseResult = await Purchases.purchasePackage(package);
      return purchaseResult.customerInfo;
    } catch (e) {
      return null;
    }
  }


  /// Restore purchases
  static Future<CustomerInfo?> restorePurchases() async {
    try {
      return await Purchases.restorePurchases();
    } catch (e) {
      return null;
    }
  }

  static Future<void> showCustomerCenter() async {
    try {
      await Purchases.showInAppMessages();
    } catch (e) {
      // handle error
    }
  }

  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      return null;
    }
  }
}
