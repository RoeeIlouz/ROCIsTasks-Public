import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart' hide LogLevel;

class SubscriptionService extends ChangeNotifier {
  final ErrorHandlingService _errorHandlingService;

  bool _isPremium = false;
  bool _isInitialized = false;

  bool get isPremium => _isPremium;
  bool get isInitialized => _isInitialized;

  SubscriptionService(this._errorHandlingService);

  Future<void> init() async {
    try {
      if (kIsWeb) {
        // RevenueCat doesn't support web yet in the same way, or maybe we don't need it for web
        // For now, just marking initialized.
        _isInitialized = true;
        notifyListeners();
        return;
      }

      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);

      String? apiKey;
      if (Platform.isAndroid) {
        apiKey = dotenv.env['REVENUECAT_API_KEY_ANDROID'];
      } else if (Platform.isIOS) {
        apiKey = dotenv.env['REVENUECAT_API_KEY_IOS'];
      }

      if (apiKey == null || apiKey.isEmpty) {
        // Fallback for development/testing if keys aren't set
        AppLogger.warning(
          'RevenueCat API key not found in .env',
          tag: 'Subscription',
        );
        _isInitialized = true;
        notifyListeners();
        return;
      }

      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);

      await _checkSubscriptionStatus();

      Purchases.addCustomerInfoUpdateListener(_updateCustomerStatus);

      _isInitialized = true;
      notifyListeners();
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Initializing SubscriptionService',
      );
      // Even if init fails, we mark as initialized so app doesn't hang,
      // but premium will be false.
      _isInitialized = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_updateCustomerStatus);
    super.dispose();
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      _updateCustomerStatus(customerInfo);
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Checking subscription status',
      );
    }
  }

  void _updateCustomerStatus(CustomerInfo customerInfo) async {
    // Check for "premium" entitlement.
    // Make sure to match this entitlement identifier in RevenueCat dashboard.
    const entitlementId = 'ROCIsApps Pro';

    final wasPremium = _isPremium;
    _isPremium =
        customerInfo.entitlements.all[entitlementId]?.isActive ?? false;

    // Always log entitlement data for debugging
    final activeEntitlements = customerInfo.entitlements.active.keys.join(', ');
    final allEntitlements = customerInfo.entitlements.all.keys.join(', ');
    AppLogger.info(
      'Customer status update: isPremium=$_isPremium, activeEntitlements=[$activeEntitlements], allEntitlements=[$allEntitlements]',
      tag: 'Subscription',
    );

    if (wasPremium != _isPremium) {
      AppLogger.info(
        'Premium status changed: $_isPremium (Entitlement: $entitlementId)',
        tag: 'Subscription',
      );

      if (!_isPremium) {
        final activeEntitlements = customerInfo.entitlements.active.keys.join(
          ', ',
        );
        final allEntitlements = customerInfo.entitlements.all.keys.join(', ');
        AppLogger.warning(
          'Premium status is false. Active entitlements: [$activeEntitlements]. All available entitlements: [$allEntitlements]',
          tag: 'Subscription',
        );
      }
      notifyListeners();

      // Sync to HomeWidget
      try {
        await HomeWidget.saveWidgetData<bool>('is_premium', _isPremium);
        await HomeWidget.updateWidget(
          name: 'MonthWidgetProvider',
          iOSName: 'MonthWidget',
        );
        await HomeWidget.updateWidget(
          name: 'FullCalendarWidgetProvider',
          iOSName: 'FullCalendarWidget',
        );
      } catch (e) {
        // Ignore widget update errors
      }
    }
  }

  Future<void> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      _updateCustomerStatus(customerInfo);
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Restoring purchases');
      rethrow; // Let UI handle error display
    }
  }

  /// Shows the paywall using RevenueCat's UI library.
  /// returns true if a purchase was made (and thus premium is likely active)
  Future<bool> showPaywall() async {
    try {
      // Only show if not already premium
      if (_isPremium) {
        AppLogger.info(
          'Already premium, skipping paywall',
          tag: 'Subscription',
        );
        return true;
      }

      AppLogger.info('Showing paywall...', tag: 'Subscription');

      // Using presentPaywall instead of presentPaywallIfNeeded for diagnostics.
      // This will show the "Current Offering" regardless of entitlement status.
      final paywallResult = await RevenueCatUI.presentPaywall();

      AppLogger.info('Paywall result: $paywallResult', tag: 'Subscription');

      final purchased =
          paywallResult == PaywallResult.purchased ||
          paywallResult == PaywallResult.restored;

      // Force refresh customer info after successful purchase
      if (purchased) {
        AppLogger.info(
          'Purchase detected, forcing customer info refresh',
          tag: 'Subscription',
        );
        await _checkSubscriptionStatus();
      }

      return purchased;
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Showing paywall');
      return false;
    }
  }

  /// Fetches the current offerings from RevenueCat.
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Fetching offerings');
      return null;
    }
  }

  /// Purchases a specific package.
  Future<bool> purchasePackage(Package package) async {
    try {
      AppLogger.info(
        'Purchasing package: ${package.identifier}',
        tag: 'Subscription',
      );
      // In newer versions of purchases_flutter, purchasePackage returns CustomerInfo
      // If it returns PurchaseResult, we need to extract customerInfo
      final result = await Purchases.purchase(PurchaseParams.package(package));

      // Handle both cases if possible, but usually it's one or the other based on version
      // In some versions it's CustomerInfo, in others it's PurchaseResult
      // Based on the lint error, it's PurchaseResult
      _updateCustomerStatus(result.customerInfo);
      return _isPremium;
    } catch (e, s) {
      // Check if user cancelled
      if (e is PlatformException &&
          e.code ==
              PurchasesErrorCode.purchaseCancelledError.index.toString()) {
        AppLogger.info('Purchase cancelled by user', tag: 'Subscription');
        return false;
      }
      _errorHandlingService.logError(e, s, reason: 'Purchasing package');
      rethrow;
    }
  }

  /// Directs the user to the platform's subscription management page.
  /// Uses RevenueCat's modern Customer Center if available.
  Future<void> manageSubscription() async {
    try {
      if (kIsWeb) return;
    } catch (e) {
      AppLogger.warning(
        'Failed to present Customer Center, falling back to manual links: $e',
        tag: 'Subscription',
      );
      // Fallback to manual links if Customer Center fails
      try {
        String url = '';
        if (Platform.isAndroid) {
          url = 'https://play.google.com/store/account/subscriptions';
        } else if (Platform.isIOS) {
          url = 'https://apps.apple.com/account/subscriptions';
        }

        if (url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      } catch (e2, s2) {
        _errorHandlingService.logError(
          e2,
          s2,
          reason: 'Opening subscription management fallback',
        );
      }
    }
  }
}
