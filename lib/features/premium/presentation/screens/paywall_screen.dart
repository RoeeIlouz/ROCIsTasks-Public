import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/utils/web_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WebPaywallView();
    }

    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        PaywallView(
          onPurchaseStarted: (package) {
            // Track purchase start
          },
          onPurchaseCompleted: (customerInfo, storefront) {
            if (context.mounted) {
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.welcomeToPro)),
              );
            }
          },
          onPurchaseError: (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error.message)),
              );
            }
          },
          onRestoreCompleted: (customerInfo) {
            final isPremium =
                customerInfo.entitlements.all[AppConfig.entitlementId]
                        ?.isActive ??
                    false;

            if (isPremium) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.purchasesRestored)),
                );
                Navigator.pop(context, true);
              }
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.noActiveSubscription)),
                );
              }
            }
          },
          onRestoreError: (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error.message)),
              );
            }
          },
        ),
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context, false),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.1),
                  hoverColor: Colors.black.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class WebPaywallView extends StatefulWidget {
  const WebPaywallView({super.key});

  @override
  State<WebPaywallView> createState() => _WebPaywallViewState();
}

class _WebPaywallViewState extends State<WebPaywallView> {
  int _selectedPlanIndex = 1; // Default to Yearly Plan (index 1)
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
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
              const SizedBox(height: 24),

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
              const SizedBox(height: 20),

              // Title & Subtitle
              Text(
                l10n.webPaywallTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.webPaywallSubtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 28),

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
                    const Divider(height: 20, thickness: 0.5),
                    _buildFeatureRow(
                      context,
                      Icons.widgets_rounded,
                      l10n.premiumWidgets,
                      l10n.premiumWidgetsDesc,
                    ),
                    const Divider(height: 20, thickness: 0.5),
                    _buildFeatureRow(
                      context,
                      Icons.checklist_rounded,
                      l10n.subtasksAndChecklists,
                      l10n.subtasksAndChecklistsDesc,
                    ),
                    const Divider(height: 20, thickness: 0.5),
                    _buildFeatureRow(
                      context,
                      Icons.repeat_rounded,
                      l10n.recurringTasks,
                      l10n.recurringTasksDesc,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Pricing Plans
              Text(
                l10n.pickAPlan,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 460;
                  final cards = [
                    _buildPlanCard(
                      index: 0,
                      title: l10n.monthlyPlanTitle,
                      price: l10n.monthlyPlanPrice,
                      theme: theme,
                    ),
                    _buildPlanCard(
                      index: 1,
                      title: l10n.yearlyPlanTitle,
                      price: l10n.yearlyPlanPrice,
                      badge: l10n.yearlyPlanSaving,
                      theme: theme,
                    ),
                    _buildPlanCard(
                      index: 2,
                      title: l10n.lifetimePlanTitle,
                      price: l10n.lifetimePlanPrice,
                      badge: l10n.lifetimePlanBadge,
                      theme: theme,
                    ),
                  ];

                  if (isNarrow) {
                    return Column(
                      children: cards
                          .map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: c,
                              ))
                          .toList(),
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 8),
                      Expanded(child: cards[1]),
                      const SizedBox(width: 8),
                      Expanded(child: cards[2]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // simulated upgrade notice
              Text(
                l10n.webPaywallNotice,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),

              // Upgrade Button
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        try {
                          final authService =
                              Provider.of<AuthService>(context, listen: false);
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

                          final String baseUrl;
                          if (_selectedPlanIndex == 0) {
                            baseUrl = AppConfig.lemonSqueezyMonthlyUrl;
                          } else if (_selectedPlanIndex == 1) {
                            baseUrl = AppConfig.lemonSqueezyYearlyUrl;
                          } else {
                            baseUrl = AppConfig.lemonSqueezyLifetimeUrl;
                          }

                           final separator = baseUrl.contains('?') ? '&' : '?';
                           final checkoutUrl =
                              '$baseUrl${separator}checkout[custom][user_id]=$userId';

                          openLemonSqueezyCheckout(checkoutUrl);
                          if (context.mounted) {
                            Navigator.pop(context, false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Opening checkout...'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error launching checkout: $e'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      },
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
                        l10n.webSimulatedUpgradeBtn,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
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
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  price,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -30,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
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
}
