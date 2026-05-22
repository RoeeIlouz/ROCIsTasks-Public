import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:intl/intl.dart';

class CompletionChart extends StatelessWidget {
  const CompletionChart({super.key});

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final theme = Theme.of(context);
    
    // Process data: group completed tasks by date for the last 7 days
    final now = DateTime.now();
    final last7Days = List.generate(7, (index) => 
      DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - index))
    );

    final allTasks = taskProvider.allTasks;
    
    final counts = last7Days.map((day) {
      return allTasks.where((t) {
        if (!t.isCompleted || t.completedAt == null) return false;
        return t.completedAt!.year == day.year &&
               t.completedAt!.month == day.month &&
               t.completedAt!.day == day.day;
      }).length;
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= last7Days.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('E').format(last7Days[value.toInt()])[0],
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(counts.length, (index) => 
              FlSpot(index.toDouble(), counts[index].toDouble())
            ),
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
