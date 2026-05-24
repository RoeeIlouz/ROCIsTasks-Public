import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class CategoryDistributionChart extends StatelessWidget {
  const CategoryDistributionChart({super.key});

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    final allTasks = taskProvider.allTasks;

    if (allTasks.isEmpty) {
      return Center(child: Text(l10n.noTaskDataAvailable));
    }
    
    // Count tasks per category
    final Map<String, int> categoryCounts = {};
    for (var task in allTasks) {
      const noCategoryKey = '__no_category__';
      final categoryId = task.categoryId ?? noCategoryKey;
      categoryCounts[categoryId] = (categoryCounts[categoryId] ?? 0) + 1;
    }

    final List<PieChartSectionData> sections = categoryCounts.entries.map((entry) {
      final category = entry.key == '__no_category__'
          ? null
          : taskProvider.getCategoryById(entry.key);
      final color = category != null ? Color(category.colorValue) : theme.disabledColor;
      final name = category?.name ?? l10n.noCategory;
      
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${((entry.value / allTasks.length) * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: _buildBadge(name, color),
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();

    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 40,
        sections: sections,
      ),
    );
  }

  Widget _buildBadge(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        name,
        style: GoogleFonts.outfit(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

