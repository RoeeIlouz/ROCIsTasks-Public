import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Stack(
      children: [
        Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.rocisTasksPro,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.unlockFullPotential,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _BenefitRow(
                      icon: Icons.dashboard_customize_rounded,
                      title: l10n.unlimitedCategories,
                      subtitle: l10n.unlimitedCategoriesDesc,
                    ),
                    const SizedBox(height: 12),
                    _BenefitRow(
                      icon: Icons.widgets_rounded,
                      title: l10n.premiumWidgets,
                      subtitle: l10n.premiumWidgetsDesc,
                    ),
                    const SizedBox(height: 12),
                    _BenefitRow(
                      icon: Icons.checklist_rounded,
                      title: l10n.subtasksAndChecklists,
                      subtitle: l10n.subtasksAndChecklistsDesc,
                    ),
                    const SizedBox(height: 12),
                    _BenefitRow(
                      icon: Icons.repeat_rounded,
                      title: l10n.recurringTasks,
                      subtitle: l10n.recurringTasksDesc,
                    ),
                    const SizedBox(height: 12),
                    _BenefitRow(
                      icon: Icons.lock_rounded,
                      title: l10n.privateMode,
                      subtitle: l10n.privateModeSubtitle,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PaywallView(
                onPurchaseStarted: (package) {},
                onPurchaseCompleted: (customerInfo, storefront) {
                  if (context.mounted) {
                    Navigator.pop(context);
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
                      Navigator.pop(context);
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
            ),
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
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
  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.75,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
