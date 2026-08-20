import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:rocis_tasks/features/premium/presentation/screens/paywall_screen.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

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
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.rocisTasksPro,
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
                      _buildHero(context, l10n),
                      const SizedBox(height: 32),
                      GlassContainer(
                        borderRadius: BorderRadius.circular(24),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            _buildFeature(
                              context,
                              Icons.dashboard_customize_rounded,
                              l10n.unlimitedCategories,
                              l10n.unlimitedCategoriesDesc,
                              isLast: false,
                            ),
                            _buildFeature(
                              context,
                              Icons.widgets_rounded,
                              l10n.premiumWidgets,
                              l10n.premiumWidgetsDesc,
                              isLast: false,
                            ),
                            _buildFeature(
                              context,
                              Icons.checklist_rounded,
                              l10n.subtasksAndChecklists,
                              l10n.subtasksAndChecklistsDesc,
                              isLast: false,
                            ),
                            _buildFeature(
                              context,
                              Icons.repeat_rounded,
                              l10n.recurringTasks,
                              l10n.recurringTasksDesc,
                              isLast: false,
                            ),
                            _buildFeature(
                              context,
                              Icons.lock_rounded,
                              l10n.privateMode,
                              l10n.privateModeSubtitle,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (subscriptionService.isPremium)
                        _buildActiveStatus(context, l10n)
                      else
                        _buildSubscribeButton(context, subscriptionService, l10n),
                      const SizedBox(height: 16),
                      _buildRestoreButton(context, subscriptionService, l10n),
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

  Widget _buildHero(BuildContext context, AppLocalizations l10n) {
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
            l10n.upgradeToPro,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.unlockFullPotential,
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
    String description, {
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
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
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
      ],
    );
  }

  Widget _buildSubscribeButton(
    BuildContext context,
    SubscriptionService subscriptionService,
    AppLocalizations l10n,
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
        l10n.viewPricingPlans,
        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActiveStatus(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green),
              const SizedBox(width: 12),
              Text(
                l10n.proSubscriptionActive,
                style: GoogleFonts.outfit(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreButton(
    BuildContext context,
    SubscriptionService subscriptionService,
    AppLocalizations l10n,
  ) {
    return TextButton(
      onPressed: _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);
              try {
                await subscriptionService.restorePurchases();
                if (context.mounted) {
                  if (subscriptionService.isPremium) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.purchasesRestored)),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.noActiveSubscription)),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.failedToRestore)),
                  );
                }
              } finally {
                if (context.mounted) setState(() => _isLoading = false);
              }
            },
      child: Text(
        l10n.restorePurchases,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
      ),
    );
  }
}
