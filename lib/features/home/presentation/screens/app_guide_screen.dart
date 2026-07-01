import 'package:flutter/material.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class AppGuideScreen extends StatelessWidget {
  const AppGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appGuideTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGuideSection(
            context,
            l10n.features,
            [
              _GuideItem(
                icon: Icons.check_circle_outline,
                title: l10n.tasks,
                description: l10n.guideTaskDesc,
              ),
              _GuideItem(
                icon: Icons.calendar_month,
                title: l10n.calendar,
                description: l10n.guideCalendarDesc,
              ),
              _GuideItem(
                icon: Icons.category,
                title: l10n.categories,
                description: l10n.guideCategoriesDesc,
              ),
              _GuideItem(
                icon: Icons.flag_outlined,
                title: l10n.priority,
                description: l10n.guidePriorityDesc,
              ),
              _GuideItem(
                icon: Icons.push_pin_outlined,
                title: l10n.pinTask,
                description: l10n.guidePinningDesc,
              ),
              _GuideItem(
                icon: Icons.checklist_rtl_outlined,
                title: l10n.subtasksAndChecklists,
                description: l10n.subtasksAndChecklistsDesc,
              ),
              _GuideItem(
                icon: Icons.attachment_rounded,
                title: l10n.attachments,
                description: l10n.guideAttachmentsDesc,
              ),
              _GuideItem(
                icon: Icons.lock_outline_rounded,
                title: l10n.privateMode,
                description: l10n.privateModeSubtitle,
              ),
              _GuideItem(
                icon: Icons.event_available_rounded,
                title: l10n.syncWithGoogleCalendar,
                description: l10n.syncWithGoogleCalendarSubtitle,
              ),
              _GuideItem(
                icon: Icons.notifications_active,
                title: l10n.guideNotificationsTitle,
                description: l10n.guideNotificationsDesc,
              ),
              _GuideItem(
                icon: Icons.sync,
                title: l10n.guideCloudSyncTitle,
                description: l10n.guideCloudSyncDesc,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildGuideSection(
            context,
            l10n.howToUse,
            [
              _GuideItem(
                icon: Icons.add,
                title: l10n.guideAddingTasksTitle,
                description: l10n.guideAddingTasksDesc,
              ),
              _GuideItem(
                icon: Icons.swipe,
                title: l10n.guideGesturesTitle,
                description: l10n.guideGesturesDesc,
              ),
              _GuideItem(
                icon: Icons.widgets,
                title: l10n.guideWidgetsTitle,
                description: l10n.guideWidgetsDesc,
              ),
              _GuideItem(
                icon: Icons.settings,
                title: l10n.guideCustomizationTitle,
                description: l10n.guideCustomizationDesc,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildGuideSection(
            context,
            l10n.searchSymbols,
            [
              _GuideItem(
                icon: Icons.search,
                title: l10n.searchSymbolsDesc,
                description: '',
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              l10n.guideHappyOrganizing,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGuideSection(BuildContext context, String title, List<_GuideItem> items) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
        GlassContainer(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(items.length, (index) {
              final item = items[index];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < items.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.dividerColor.withValues(alpha: 0.08),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _GuideItem {
  final IconData icon;
  final String title;
  final String description;

  _GuideItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
