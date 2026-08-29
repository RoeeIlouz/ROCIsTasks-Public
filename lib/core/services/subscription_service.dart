import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/config/router.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart' hide LogLevel;
import 'package:rocis_tasks/features/premium/presentation/screens/paywall_screen.dart';

class SubscriptionService extends ChangeNotifier {
  final ErrorHandlingService _errorHandlingService;

  bool _isPremium = false;
  bool _isInitialized = false;
  bool _isConfigured = false;
  String? _configurationError;
  String? _syncedAuthUserId;
  StreamSubscription<DocumentSnapshot>? _webSubscriptionListener;

  // Track sources separately for cross-platform synchronization
  bool _firestorePremium = false;
  bool _revenueCatPremium = false;

  bool get isPremium => _isPremium;
  bool get isInitialized => _isInitialized;
  String? get configurationError => _configurationError;

  SubscriptionService(this._errorHandlingService);

  Future<void> init() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        _firestorePremium = prefs.getBool('web_is_premium') ?? false;
        _isPremium = _firestorePremium;
        _isInitialized = true;
        notifyListeners();
        return;
      }

      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);

      String? apiKey;
      if (Platform.isAndroid) {
        final fromDefine = const String.fromEnvironment(
          'REVENUECAT_API_KEY_ANDROID',
        );
        apiKey = fromDefine.isNotEmpty ? fromDefine : null;
      } else if (Platform.isIOS) {
        final fromDefine = const String.fromEnvironment(
          'REVENUECAT_API_KEY_IOS',
        );
        apiKey = fromDefine.isNotEmpty ? fromDefine : null;
      }

      if (apiKey == null && dotenv.isInitialized) {
        if (Platform.isAndroid) {
          apiKey = dotenv.env['REVENUECAT_API_KEY_ANDROID'];
        } else if (Platform.isIOS) {
          apiKey = dotenv.env['REVENUECAT_API_KEY_IOS'];
        }
      }

      if (apiKey == null || apiKey.isEmpty) {
        _configurationError =
            'Subscriptions are not configured. RevenueCat API key missing.';
        if (AppConfig.isProduction) {
          AppLogger.critical(_configurationError!, tag: 'Subscription');
        } else {
          AppLogger.warning(_configurationError!, tag: 'Subscription');
        }
        _isInitialized = true;
        notifyListeners();
        return;
      }

      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      _isConfigured = true;

      // Check subscription status non-blockingly so startup is instant
      unawaited(_checkSubscriptionStatus());

      Purchases.addCustomerInfoUpdateListener(_updateCustomerStatus);

      _configurationError = null;
      _isInitialized = true;
      try {
        HomeWidget.saveWidgetData<bool>('is_premium', _isPremium);
      } catch (_) {}
      notifyListeners();
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Initializing SubscriptionService',
      );
      // Even if init fails, we mark as initialized so app doesn't hang,
      // but premium will be false.
      _configurationError ??= 'Subscriptions failed to initialize.';
      _isInitialized = true;
      try {
        HomeWidget.saveWidgetData<bool>('is_premium', false);
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> syncWithAuthUserId(String? authUserId) async {
    final normalized = authUserId?.trim();
    if (_syncedAuthUserId == normalized) return;
    _syncedAuthUserId = normalized;

    await _webSubscriptionListener?.cancel();
    _firestorePremium = false;

    if (normalized == null || normalized.isEmpty) {
      _isPremium = false;
      _revenueCatPremium = false;
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('web_is_premium');
      }
      if (!kIsWeb && _isConfigured) {
        try {
          final customerInfo = await Purchases.logOut();
          _updateCustomerStatus(customerInfo);
        } catch (e) {
          // Ignore logout errors
        }
      }
      _updatePremiumState();
      return;
    }

    // Start listening to Firestore (cross-platform)
    _webSubscriptionListener = FirebaseFirestore.instance
        .collection('users')
        .doc(normalized)
        .snapshots()
        .listen((snapshot) async {
          final data = snapshot.data();
          final cloudPremium = data?['is_premium'] == true;
          if (_firestorePremium != cloudPremium) {
            _firestorePremium = cloudPremium;
            if (kIsWeb) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('web_is_premium', cloudPremium);
            }
            _updatePremiumState();
          }
        });

    if (!kIsWeb && _isConfigured) {
      try {
        final result = await Purchases.logIn(normalized);
        _updateCustomerStatus(result.customerInfo);
      } catch (e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'Syncing subscription user id',
        );
        await _checkSubscriptionStatus();
      }
    }
  }

  @override
  void dispose() {
    _webSubscriptionListener?.cancel();
    if (!kIsWeb) {
      Purchases.removeCustomerInfoUpdateListener(_updateCustomerStatus);
    }
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

  void _updatePremiumState() {
    final newPremium = _revenueCatPremium || _firestorePremium;
    if (_isPremium != newPremium) {
      _isPremium = newPremium;
      notifyListeners();

      // Sync to HomeWidget
      try {
        HomeWidget.saveWidgetData<bool>('is_premium', _isPremium);
        final providers = [
          ('TaskWidgetProvider', 'TaskWidget'),
          ('FullCalendarWidgetProvider', 'FullCalendarWidget'),
          ('TodayAgendaWidgetProvider', 'TodayAgendaWidget'),
          ('MonthAgendaWidgetProvider', 'MonthAgendaWidget'),
          ('TimelineAgendaWidgetProvider', 'TimelineAgendaWidget'),
          ('QuickActionWidgetProvider', 'QuickActionWidget'),
          ('UpNextWidgetProvider', 'UpNextWidget'),
        ];
        for (final p in providers) {
          HomeWidget.updateWidget(name: p.$1, iOSName: p.$2);
        }
      } catch (e) {
        // Ignore widget update errors
      }
    }
  }

  Future<void> _backSyncToFirestore(String userId) async {
    try {
      if (!_firestorePremium) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'is_premium': true,
          'subscription_status': 'active',
          'last_synced_from_mobile': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _firestorePremium = true;
        _updatePremiumState();
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to back-sync mobile premium status to Firestore: $e',
        tag: 'Subscription',
      );
    }
  }

  Future<void> _updateCustomerStatus(CustomerInfo customerInfo) async {
    // Check for "premium" entitlement.
    // Make sure to match this entitlement identifier in RevenueCat dashboard.
    const entitlementId = AppConfig.entitlementId;

    final wasPremium = _isPremium;
    _revenueCatPremium =
        customerInfo.entitlements.all[entitlementId]?.isActive ?? false;

    _updatePremiumState();

    // Always log entitlement data for debugging
    final activeEntitlements = customerInfo.entitlements.active.keys.join(', ');
    final allEntitlements = customerInfo.entitlements.all.keys.join(', ');
    AppLogger.info(
      'Customer status update: isPremium=$_isPremium (RevenueCat=$_revenueCatPremium, Firestore=$_firestorePremium), activeEntitlements=[$activeEntitlements], allEntitlements=[$allEntitlements]',
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
    }

    if (_revenueCatPremium && _syncedAuthUserId != null) {
      _backSyncToFirestore(_syncedAuthUserId!);
    }
  }

  Future<void> restorePurchases() async {
    if (kIsWeb) return;
    if (!_isConfigured) return;
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      _updateCustomerStatus(customerInfo);
    } catch (e, s) {
      if (e is PlatformException &&
          e.code ==
              PurchasesErrorCode.receiptAlreadyInUseError.index.toString()) {
        return;
      }
      _errorHandlingService.logError(e, s, reason: 'Restoring purchases');
      rethrow; // Let UI handle error display
    }
  }

  /// Shows the paywall using RevenueCat's UI library.
  /// returns true if a purchase was made (and thus premium is likely active)
  Future<bool> showPaywall() async {
    if (kIsWeb) {
      if (_isPremium) return true;
      final context = AppRouter.navigatorKey.currentContext;
      if (context != null) {
        final result = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => const PaywallScreen(),
        );
        return result ?? false;
      }
      return false;
    }
    if (!_isConfigured) return false;
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

  /// Toggles premium status specifically for the web platform.
  Future<void> toggleWebPremium(bool value) async {
    if (!kIsWeb) return;
    _firestorePremium = value;
    _updatePremiumState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('web_is_premium', value);
  }

  /// Fetches the current offerings from RevenueCat.
  Future<Offerings?> getOfferings() async {
    if (kIsWeb) return null;
    if (!_isConfigured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Fetching offerings');
      return null;
    }
  }

  /// Purchases a specific package.
  Future<bool> purchasePackage(Package package) async {
    if (kIsWeb) return false;
    if (!_isConfigured) return false;
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
      if (!_isConfigured) return;
      await RevenueCatUI.presentCustomerCenter();
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
