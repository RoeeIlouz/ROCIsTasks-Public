import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/utils/web_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedPlanIndex = 1; // Default to Yearly Plan (index 1)
  bool _isLoading = false;
  Package? _monthlyPackage;
  Package? _yearlyPackage;
  Package? _lifetimePackage;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadOfferings();
    }
  }

  Future<void> _loadOfferings() async {
    final subscriptionService =
        Provider.of<SubscriptionService>(context, listen: false);
    final offerings = await subscriptionService.getOfferings();
    if (mounted && offerings != null && offerings.current != null) {
      setState(() {
        final current = offerings.current!;
        _monthlyPackage = current.monthly ??
            current.availablePackages.where((p) => p.packageType == PackageType.monthly).firstOrNull;
        _yearlyPackage = current.annual ??
            current.availablePackages.where((p) => p.packageType == PackageType.annual).firstOrNull;
        _lifetimePackage = current.lifetime ??
            current.availablePackages.where((p) => p.packageType == PackageType.lifetime).firstOrNull;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    final monthlyPrice = _monthlyPackage?.storeProduct.priceString ?? l10n.monthlyPlanPrice;
    final yearlyPrice = _yearlyPackage?.storeProduct.priceString ?? l10n.yearlyPlanPrice;
    final lifetimePrice = _lifetimePackage?.storeProduct.priceString ?? l10n.lifetimePlanPrice;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Close handle
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.stars_rounded,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title & Subtitle
                  Text(
                    kIsWeb ? l10n.webPaywallTitle : l10n.upgradeToPro,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kIsWeb ? l10n.webPaywallSubtitle : l10n.unlockFullPotential,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Premium features list
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildFeatureRow(
                          context,
                          Icons.dashboard_customize_rounded,
                          l10n.unlimitedCategories,
                          l10n.unlimitedCategoriesDesc,
                        ),
                        const Divider(height: 16, thickness: 0.5),
                        _buildFeatureRow(
                          context,
                          Icons.widgets_rounded,
                          l10n.premiumWidgets,
                          l10n.premiumWidgetsDesc,
                        ),
                        const Divider(height: 16, thickness: 0.5),
                        _buildFeatureRow(
                          context,
                          Icons.checklist_rounded,
                          l10n.subtasksAndChecklists,
                          l10n.subtasksAndChecklistsDesc,
                        ),
                        const Divider(height: 16, thickness: 0.5),
                        _buildFeatureRow(
                          context,
                          Icons.repeat_rounded,
                          l10n.recurringTasks,
                          l10n.recurringTasksDesc,
                        ),
                        const Divider(height: 16, thickness: 0.5),
                        _buildFeatureRow(
                          context,
                          Icons.lock_rounded,
                          l10n.privateMode,
                          l10n.privateModeSubtitle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pricing Plans
                  Text(
                    l10n.pickAPlan,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPlanCard(
                          index: 0,
                          title: l10n.monthlyPlanTitle,
                          price: monthlyPrice,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPlanCard(
                          index: 1,
                          title: l10n.yearlyPlanTitle,
                          price: yearlyPrice,
                          badge: l10n.yearlyPlanSaving,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPlanCard(
                          index: 2,
                          title: l10n.lifetimePlanTitle,
                          price: lifetimePrice,
                          badge: l10n.lifetimePlanBadge,
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Notice
                  Text(
                    l10n.webPaywallNotice,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Upgrade / Subscribe Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handlePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            l10n.upgradeToPro,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  // Mobile Restore Purchases & Legal links
                  if (!kIsWeb) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _isLoading ? null : _handleRestore,
                          child: Text(
                            l10n.restorePurchases,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          ' • ',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _launchURL(AppConfig.termsOfServiceUrl),
                          child: Text(
                            l10n.termsOfService,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          ' • ',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _launchURL(AppConfig.privacyPolicyUrl),
                          child: Text(
                            l10n.privacyPolicy,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context, false),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final userId = authService.currentUser?.uid;

        if (userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.signInToSync),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        final baseUrl = switch (_selectedPlanIndex) {
          0 => AppConfig.lemonSqueezyMonthlyUrl,
          1 => AppConfig.lemonSqueezyYearlyUrl,
          2 => AppConfig.lemonSqueezyLifetimeUrl,
          _ => AppConfig.lemonSqueezyYearlyUrl,
        };

        final separator = baseUrl.contains('?') ? '&' : '?';
        final checkoutUrl = '$baseUrl${separator}checkout[custom][user_id]=$userId';

        openLemonSqueezyCheckout(checkoutUrl);
        if (mounted) {
          Navigator.pop(context, false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening checkout...'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Mobile In-App Purchase via RevenueCat
      final subscriptionService =
          Provider.of<SubscriptionService>(context, listen: false);

      final selectedPackage = switch (_selectedPlanIndex) {
        0 => _monthlyPackage,
        1 => _yearlyPackage,
        2 => _lifetimePackage,
        _ => _yearlyPackage,
      };

      if (selectedPackage != null) {
        final isSuccess = await subscriptionService.purchasePackage(selectedPackage);
        if (mounted) {
          if (isSuccess) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.welcomeToPro)),
            );
          }
        }
      } else {
        // Fallback if offering packages aren't loaded from RevenueCat store yet
        await subscriptionService.showPaywall();
        if (mounted && subscriptionService.isPremium) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.welcomeToPro)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      final subscriptionService =
          Provider.of<SubscriptionService>(context, listen: false);
      await subscriptionService.restorePurchases();
      if (mounted) {
        if (subscriptionService.isPremium) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.purchasesRestored)),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.noActiveSubscription)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToRestore)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildFeatureRow(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required int index,
    required String title,
    required String price,
    String? badge,
    required ThemeData theme,
  }) {
    final isSelected = _selectedPlanIndex == index;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    price,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -26,
                right: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
