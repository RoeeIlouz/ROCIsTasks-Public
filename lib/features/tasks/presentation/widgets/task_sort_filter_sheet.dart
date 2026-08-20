import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return GlassContainer(
              opacity: 0.9,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    l10n.sortAndFilter,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Sorting Section
                  Text(
                    l10n.sortBy,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GlassContainer(
                    borderRadius: BorderRadius.circular(12),
                    child: RadioGroup<TaskSortOption>(
                      groupValue: provider.currentSortOption,
                      onChanged: (value) {
                        if (value != null) {
                          provider.setSortOption(value);
                        }
                      },
                      child: Column(
                        children: [
                          _buildSortOption(
                            context,
                            l10n.date,
                            TaskSortOption.dueDate,
                            provider,
                          ),
                          const Divider(height: 1),
                          _buildSortOption(
                            context,
                            l10n.priority,
                            TaskSortOption.priority,
                            provider,
                          ),
                          const Divider(height: 1),
                          _buildSortOption(
                            context,
                            l10n.title,
                            TaskSortOption.title,
                            provider,
                          ),
                          const Divider(height: 1),
                          _buildSortOption(
                            context,
                            l10n.createdDate,
                            TaskSortOption.dateCreated,
                            provider,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Date Filtering Section
                  Text(
                    l10n.dateRange,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDateFilterChip(context, l10n.all, DateTimeFilterOption.all, provider),
                      _buildDateFilterChip(context, l10n.filterToday, DateTimeFilterOption.today, provider),
                      _buildDateFilterChip(context, l10n.filterThisWeek, DateTimeFilterOption.thisWeek, provider),
                      _buildDateFilterChip(context, l10n.filterOverdue, DateTimeFilterOption.overdue, provider),
                      _buildDateFilterChip(context, l10n.filterNoDate, DateTimeFilterOption.noDate, provider),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Filtering Section
                  Text(
                    l10n.filterByCategory,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(l10n.all),
                        selected: provider.selectedCategoryIds.isEmpty,
                        onSelected: (selected) {
                          if (selected) {
                            provider.clearCategoryFilters();
                          }
                        },
                      ),
                      ...categories.map((category) {
                        return FilterChip(
                          label: Text(category.name),
                          backgroundColor: Color(
                            category.colorValue,
                          ).withValues(alpha: 0.1),
                          selectedColor: Color(
                            category.colorValue,
                          ).withValues(alpha: 0.3),
                          selected: provider.selectedCategoryIds.contains(
                            category.id,
                          ),
                          onSelected: (selected) {
                            provider.toggleCategoryFilter(category.id);
                          },
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Show Completed Toggle
                  SwitchListTile(
                    title: Text(l10n.showCompletedTasks),
                    value: provider.showCompleted,
                    onChanged: (value) => provider.toggleShowCompleted(value),
                    secondary: const Icon(Icons.check_circle_outline),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.done),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOption(
    BuildContext context,
    String title,
    TaskSortOption option,
    TaskProvider provider,
  ) {
    return RadioListTile<TaskSortOption>(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: Text(title),
      value: option,
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
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => provider.setDateFilter(option),
    );
  }
}
