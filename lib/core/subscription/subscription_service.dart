import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Thin wrapper around the RevenueCat SDK. Owns SDK configuration and all
/// direct Purchases.* calls so the rest of the app never touches the SDK
/// surface directly.
class SubscriptionService {
  /// Must match the entitlement identifier configured in the RevenueCat
  /// dashboard (Entitlements tab). See README instructions after setup.
  static const String entitlementId = 'pro';

  static bool _configured = false;

  /// Configures the RevenueCat SDK. Safe to call once at app startup.
  /// If no API key is present in .env, subscriptions are simply disabled —
  /// the app continues to run on the free tier without throwing.
  static Future<void> init() async {
    if (_configured) return;

    String? apiKey;
    if (Platform.isAndroid) {
      apiKey = dotenv.env['REVENUECAT_ANDROID_API_KEY'];
    } else if (Platform.isIOS) {
      apiKey = dotenv.env['REVENUECAT_IOS_API_KEY'];
    }

    if (apiKey == null || apiKey.isEmpty) {
      // Not configured yet — app remains fully functional on the free tier.
      return;
    }

    try {
      await Purchases.setLogLevel(LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(apiKey));
      _configured = true;
    } catch (_) {
      // Never let a misconfigured SDK crash app startup.
      _configured = false;
    }
  }

  static bool get isConfigured => _configured;

  /// Cap on the read-only startup calls. Without this a stalled Play Billing
  /// connection leaves them pending indefinitely, and any UI state keyed off
  /// their completion never settles. Purchase and restore are deliberately
  /// NOT capped — the user may sit on the Play sheet for minutes.
  static const Duration _readTimeout = Duration(seconds: 20);

  static Future<CustomerInfo?> getCustomerInfo() async {
    if (!_configured) return null;
    try {
      return await Purchases.getCustomerInfo().timeout(_readTimeout);
    } catch (_) {
      return null;
    }
  }

  static bool hasProEntitlement(CustomerInfo info) {
    return info.entitlements.active.containsKey(entitlementId);
  }

  static Future<Offerings?> getOfferings() async {
    if (!_configured) return null;
    try {
      return await Purchases.getOfferings().timeout(_readTimeout);
    } catch (_) {
      return null;
    }
  }

  /// Note: `Purchases.purchasePackage` resolves to [CustomerInfo] directly in
  /// purchases_flutter 8.x — there is no wrapper result object to unwrap.
  static Future<CustomerInfo> purchasePackage(Package package) =>
      Purchases.purchasePackage(package);

  static Future<CustomerInfo> restorePurchases() async {
    return await Purchases.restorePurchases();
  }

  static void addCustomerInfoListener(void Function(CustomerInfo) listener) {
    if (!_configured) return;
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  static void removeCustomerInfoListener(
      void Function(CustomerInfo) listener) {
    if (!_configured) return;
    Purchases.removeCustomerInfoUpdateListener(listener);
  }
}
