import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Pick a Plan",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: PaywallView(
        onPurchaseStarted: (package) {
          // Track purchase start
        },
        onPurchaseCompleted: (customerInfo, storefront) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Welcome to Pro!")));
        },
        onRestoreCompleted: (customerInfo) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Purchases restored!")));
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "By continuing, you agree to our",
                style: GoogleFonts.outfit(fontSize: 12),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _launchURL(AppConfig.privacyPolicyUrl),
                    child: Text(
                      "Privacy Policy",
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                  ),
                  Text("&", style: GoogleFonts.outfit(fontSize: 12)),
                  TextButton(
                    onPressed: () => _launchURL(AppConfig.termsOfServiceUrl),
                    child: Text(
                      "Terms of Service",
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
