import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/analytics/presentation/widgets/completion_chart.dart';
import 'package:rocis_tasks/features/analytics/presentation/widgets/category_distribution_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSummaryCards(context, taskProvider, l10n),
                const SizedBox(height: 24),
                Text(
                  l10n.productivityTrend,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  height: 250,
                  child: CompletionChart(),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.categoryBreakdown,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  height: 300,
                  child: CategoryDistributionChart(),
                ),
                const SizedBox(height: 100), // Space for FAB/BottomNav
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    TaskProvider provider,
    AppLocalizations l10n,
  ) {
    final allTasks = provider.allTasks;
    final completedTasks = allTasks.where((t) => t.isCompleted).length;
    final pendingTasks = allTasks.where((t) => !t.isCompleted).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            l10n.completed,
            completedTasks.toString(),
            Icons.check_circle_outline,
            Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            context,
            l10n.pending,
            pendingTasks.toString(),
            Icons.pending_actions,
            Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
