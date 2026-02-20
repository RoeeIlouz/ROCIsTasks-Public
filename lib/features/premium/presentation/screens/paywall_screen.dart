import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  bool _isLoading = true;
  Package? _selectedPackage;

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    final subService = Provider.of<SubscriptionService>(context, listen: false);
    final offerings = await subService.getOfferings();
    if (mounted) {
      setState(() {
        _offerings = offerings;
        _isLoading = false;
        if (offerings?.current != null &&
            offerings!.current!.availablePackages.isNotEmpty) {
          _selectedPackage = offerings.current!.availablePackages.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Elevate Your Workflow",
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _buildContent(context),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isLoading ? null : _buildBottomBar(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final offering = _offerings?.current;

    if (offering == null) {
      return Center(
        child: Text(
          "No plans available at the moment.",
          style: GoogleFonts.outfit(fontSize: 16),
        ),
      );
    }

    return AnimationLimiter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 375),
          childAnimationBuilder: (widget) => FadeInAnimation(child: widget),
          children: [
            Text(
              "Choose Your Plan",
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...offering.availablePackages.map(
              (package) => _buildPackageCard(package),
            ),
            const SizedBox(height: 32),
            _buildFeatureList(context),
            const SizedBox(height: 16),
            _buildLegalLinks(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(Package package) {
    final theme = Theme.of(context);
    final isSelected = _selectedPackage?.identifier == package.identifier;
    final product = package.storeProduct;

    return GestureDetector(
      onTap: () => setState(() => _selectedPackage = package),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.packageType
                        .toString()
                        .split('.')
                        .last
                        .toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.title.split('(').first.trim(),
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  product.priceString,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (package.packageType == PackageType.annual)
                  Text(
                    "Best Value",
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList(BuildContext context) {
    return Column(
      children: [
        _buildFeatureItem(Icons.check_circle_outline, "Unlimited Categories"),
        _buildFeatureItem(
          Icons.check_circle_outline,
          "Premium Calendar Widgets",
        ),
        _buildFeatureItem(Icons.check_circle_outline, "Full Offline Support"),
        _buildFeatureItem(Icons.check_circle_outline, "Priority Task Rules"),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.outfit(fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildLegalLinks(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      children: [
        TextButton(
          onPressed: () => _launchURL("https://rocis.co/privacy"),
          child: Text(
            "Privacy Policy",
            style: GoogleFonts.outfit(fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: () => _launchURL("https://rocis.co/terms"),
          child: Text(
            "Terms of Service",
            style: GoogleFonts.outfit(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final subService = Provider.of<SubscriptionService>(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: _selectedPackage == null
                ? null
                : () => _handlePurchase(context, subService),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              "Continue with ${_selectedPackage?.packageType.toString().split('.').last ?? ""}",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Not now",
              style: GoogleFonts.outfit(color: theme.hintColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase(
    BuildContext context,
    SubscriptionService subService,
  ) async {
    if (_selectedPackage == null) return;

    try {
      final success = await subService.purchasePackage(_selectedPackage!);
      if (success && mounted) {
        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Welcome to Pro!")));
      }
    } catch (e) {
      if (mounted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Purchase failed: $e")));
      }
    }
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
