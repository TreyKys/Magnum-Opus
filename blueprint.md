
# Project Blueprint: RevenueCat Integration

This document outlines the plan for integrating the RevenueCat SDK into the Magnum Opus Flutter application.

## 1. Overview

The goal is to add subscription-based monetization to the app using RevenueCat. This will involve:
- Installing and configuring the RevenueCat SDK.
- Creating and managing subscription products.
- Presenting a paywall to users.
- Checking for entitlements to unlock premium features.
- Allowing users to manage their subscriptions.

## 2. Style and Design

- The RevenueCat Paywall will be presented modally.
- The UI for triggering the paywall will be integrated into the existing settings screen.
- A "Manage Subscription" button will be added to the settings screen.

## 3. Features to be Implemented

### 3.1. RevenueCat SDK Integration
- **Dependencies:** Add `purchases_flutter` and `purchases_ui_flutter` to `pubspec.yaml`.
- **Initialization:** Initialize the SDK in `main.dart` with the provided API key.
- **API Key Management:** Store the API key in a separate, git-ignored file.

### 3.2. Subscription Management
- **Offerings:** Fetch the available offerings and packages from RevenueCat.
- **Purchases:** Handle the purchase flow.
- **Restore Purchases:** Implement a mechanism to restore purchases.
- **Subscription Provider:** Create a Riverpod provider to manage the user's subscription status and entitlements.

### 3.3. Entitlement Checking
- **"pro" Entitlement:** The provider will check for the "pro" entitlement.
- **Gated Features:** The number of queries and documents are restricted to users without the "pro" entitlement.

### 3.4. Paywall
- **Present Paywall:** Use `purchases_ui_flutter` to present a pre-built RevenueCat Paywall.
- **Trigger:** An "Upgrade to Pro" button on the settings screen will trigger the paywall. The paywall will also be presented when a free user hits their query or document limit.

### 3.5. Customer Center
- **Manage Subscriptions:** A "Manage Subscription" button will open the RevenueCat Customer Center.

## 4. Plan for Current Request

1.  **Create `blueprint.md`:** Done.
2.  **Install Dependencies:** Add `purchases_flutter` and `purchases_ui_flutter`.
3.  **Create `revenuecat_service.dart`:** A service to encapsulate RevenueCat logic.
4.  **Create `subscription_provider.dart`:** A Riverpod provider for subscription state.
5.  **Initialize in `main.dart`:** Configure RevenueCat on app startup.
6.  **Update `settings_screen.dart`:** Add UI elements for paywall and customer center.
7.  **Gate a feature:** Lock features behind the "pro" entitlement.
    - Create a `usage_provider.dart` to track user queries and documents.
    - Update `standalone_chat_screen.dart` to check for the "pro" entitlement and query limits.
    - Update `document_chat_screen.dart` to check for the "pro" entitlement and query limits.
    - Update `vault_screen.dart` to check for the "pro" entitlement and document limits.
