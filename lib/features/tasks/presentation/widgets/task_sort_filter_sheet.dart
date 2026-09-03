import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class TaskSortFilterSheet extends StatelessWidget {
  const TaskSortFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        final categories = provider.categories;
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);

        final hasActiveFilters =
            provider.selectedCategoryIds.isNotEmpty ||
            provider.currentDateFilter != DateTimeFilterOption.all ||
            provider.currentSortOption != TaskSortOption.dueDate ||
            !provider.showCompleted;

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return GlassContainer(
              opacity: 0.95,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.sortAndFilter,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (hasActiveFilters)
                        TextButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            provider.resetAllFilters();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(
                            l10n.resetFilters,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Sorting Section
                  Text(
                    l10n.sortBy,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSortPill(
                        context,
                        label: l10n.date,
                        icon: Icons.calendar_today_rounded,
                        option: TaskSortOption.dueDate,
                        provider: provider,
                      ),
                      _buildSortPill(
                        context,
                        label: l10n.dueDateTime,
                        icon: Icons.schedule_rounded,
                        option: TaskSortOption.dueDateTime,
                        provider: provider,
                      ),
                      _buildSortPill(
                        context,
                        label: l10n.priority,
                        icon: Icons.flag_rounded,
                        option: TaskSortOption.priority,
                        provider: provider,
                      ),
                      _buildSortPill(
                        context,
                        label: l10n.title,
                        icon: Icons.sort_by_alpha_rounded,
                        option: TaskSortOption.title,
                        provider: provider,
                      ),
                      _buildSortPill(
                        context,
                        label: l10n.createdDate,
                        icon: Icons.history_rounded,
                        option: TaskSortOption.dateCreated,
                        provider: provider,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Date Filtering Section
                  Text(
                    l10n.dateRange,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDateFilterChip(
                        context,
                        l10n.all,
                        DateTimeFilterOption.all,
                        provider,
                      ),
                      _buildDateFilterChip(
                        context,
                        l10n.filterToday,
                        DateTimeFilterOption.today,
                        provider,
                      ),
                      _buildDateFilterChip(
                        context,
                        l10n.filterThisWeek,
                        DateTimeFilterOption.thisWeek,
                        provider,
                      ),
                      _buildDateFilterChip(
                        context,
                        l10n.filterOverdue,
                        DateTimeFilterOption.overdue,
                        provider,
                      ),
                      _buildDateFilterChip(
                        context,
                        l10n.filterNoDate,
                        DateTimeFilterOption.noDate,
                        provider,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Filtering Section
                  Text(
                    l10n.filterByCategory,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(l10n.all, style: GoogleFonts.outfit()),
                        selected: provider.selectedCategoryIds.isEmpty,
                        onSelected: (selected) {
                          if (selected) {
                            HapticFeedback.lightImpact();
                            provider.clearCategoryFilters();
                          }
                        },
                      ),
                      ...categories.map((category) {
                        final isSelected = provider.selectedCategoryIds
                            .contains(category.id);
                        return FilterChip(
                          avatar: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Color(category.colorValue),
                              shape: BoxShape.circle,
                            ),
                          ),
                          label: Text(
                            category.name,
                            style: GoogleFonts.outfit(),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            HapticFeedback.lightImpact();
                            provider.toggleCategoryFilter(category.id);
                          },
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Show Completed Toggle
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.showCompletedTasks,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                      value: provider.showCompleted,
                      onChanged: (value) {
                        HapticFeedback.lightImpact();
                        provider.toggleShowCompleted(value);
                      },
                      secondary: const Icon(Icons.check_circle_outline),
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        l10n.done,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortPill(
    BuildContext context, {
    required String label,
    required IconData icon,
    required TaskSortOption option,
    required TaskProvider provider,
  }) {
    final isSelected = provider.currentSortOption == option;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        provider.setSortOption(option);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterChip(
    BuildContext context,
    String label,
    DateTimeFilterOption option,
    TaskProvider provider,
  ) {
    final isSelected = provider.currentDateFilter == option;
    return FilterChip(
      label: Text(label, style: GoogleFonts.outfit()),
      selected: isSelected,
      onSelected: (_) {
        HapticFeedback.lightImpact();
        provider.setDateFilter(option);
      },
    );
  }
}
