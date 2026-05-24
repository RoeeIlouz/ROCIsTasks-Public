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

    return Stack(
      children: [
        PaywallView(
          onPurchaseStarted: (package) {
            // Track purchase start
          },
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
