import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:rocis_tasks/features/premium/presentation/screens/paywall_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              "ROCIs Tasks Pro",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: AnimationLimiter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 375),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      horizontalOffset: 50.0,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: [
                      _buildHero(context),
                      const SizedBox(height: 32),
                      _buildFeature(
                        context,
                        Icons.dashboard_customize_rounded,
                        "Unlimited Categories",
                        "Create as many categories as you need to stay organized.",
                      ),
                      _buildFeature(
                        context,
                        Icons.widgets_rounded,
                        "Premium Widgets",
                        "Access to Month and Full Calendar home screen widgets.",
                      ),
                      _buildFeature(
                        context,
                        Icons.checklist_rounded,
                        "Subtasks & Checklists",
                        "Break down complex tasks into smaller, manageable steps.",
                      ),
                      _buildFeature(
                        context,
                        Icons.repeat_rounded,
                        "Recurring Tasks",
                        "Automate your routine with flexible repetition rules.",
                      ),
                      const SizedBox(height: 48),
                      if (subscriptionService.isPremium)
                        _buildActiveStatus(context)
                      else
                        _buildSubscribeButton(context, subscriptionService),
                      const SizedBox(height: 16),
                      _buildRestoreButton(context, subscriptionService),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, size: 64, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            "Upgrade to Pro",
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Unlock your full potential",
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(
    BuildContext context,
    SubscriptionService subscriptionService,
  ) {
    return FilledButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => const PaywallScreen(),
        );
      },
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        "View Pricing Plans",
        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActiveStatus(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green),
          const SizedBox(width: 12),
          Text(
            "Pro Subscription Active",
            style: GoogleFonts.outfit(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreButton(
    BuildContext context,
    SubscriptionService subscriptionService,
  ) {
    return TextButton(
      onPressed: _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);
              try {
                await subscriptionService.restorePurchases();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Purchases restored successfully!"),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Failed to restore purchases."),
                    ),
                  );
                }
              } finally {
                if (context.mounted) setState(() => _isLoading = false);
              }
            },
      child: Text(
        "Restore Purchases",
        style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
      ),
    );
  }
}
