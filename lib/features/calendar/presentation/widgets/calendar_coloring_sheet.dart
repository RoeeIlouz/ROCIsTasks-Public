import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/app_color_picker_sheet.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class CalendarColoringSheet extends StatelessWidget {
  const CalendarColoringSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final calendarProvider = Provider.of<CalendarProvider>(context);

    // Only show enabled calendars per user preference
    final enabledCalendars = calendarProvider.availableCalendars.where((c) {
      if (calendarProvider.selectedCalendarIds.isEmpty) return true;
      return calendarProvider.selectedCalendarIds.contains(c.id);
    }).toList();

    return GlassContainer(
      opacity: 0.95,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Consumer<CalendarColorService>(
        builder: (context, colorService, _) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.calendarColors,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await colorService.resetToDefaults();
                        if (context.mounted) {
                          await taskProvider.updateHomeWidget();
                        }
                      },
                      icon: const Icon(Icons.restore, size: 18),
                      label: Text(l10n.resetColors),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),

              // General Task & Google Calendar Colors
              _buildColorTile(
                context,
                title: l10n.taskColor,
                currentColor: colorService.taskColor,
                onTap: () {
                  AppColorPickerSheet.show(
                    context: context,
                    title: l10n.taskColor,
                    initialColor: colorService.taskColor,
                    onColorChanged: (color) async {
                      await colorService.setTaskColor(color);
                      if (context.mounted) {
                        await taskProvider.updateHomeWidget();
                      }
                    },
                  );
                },
              ),
              _buildColorTile(
                context,
                title: l10n.googleCalendarColor,
                currentColor: colorService.googleColor,
                onTap: () {
                  AppColorPickerSheet.show(
                    context: context,
                    title: l10n.googleCalendarColor,
                    initialColor: colorService.googleColor,
                    onColorChanged: (color) async {
                      await colorService.setGoogleColor(color);
                      if (context.mounted) {
                        await taskProvider.updateHomeWidget();
                      }
                    },
                  );
                },
              ),

              // Subcalendars Section
              if (calendarProvider.showGoogleCalendar && enabledCalendars.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Divider(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.subcalendars,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
                ...enabledCalendars.map((cal) {
                  final String calendarName = (cal.name != null &&
                          cal.name!.trim().isNotEmpty &&
                          cal.name!.toLowerCase() != 'unnamed' &&
                          cal.name!.toLowerCase() != 'unnamed calendar')
                      ? cal.name!
                      : (cal.accountName?.trim().isNotEmpty == true
                          ? cal.accountName!
                          : l10n.calendar);

                  final hasSubtitle = cal.accountName != null &&
                      cal.accountName!.trim().isNotEmpty &&
                      cal.accountName != calendarName;

                  final Color? nativeColor =
                      cal.color != null ? Color(cal.color!) : null;
                  final Color effectiveColor = colorService.getEffectiveSubcalendarColor(
                    cal.id,
                    nativeColor: nativeColor,
                  );
                  final bool hasCustom =
                      cal.id != null && colorService.hasCustomSubcalendarColor(cal.id!);

                  return _buildColorTile(
                    context,
                    title: calendarName,
                    subtitle: hasSubtitle ? cal.accountName : null,
                    currentColor: effectiveColor,
                    isCustom: hasCustom,
                    onTap: () {
                      AppColorPickerSheet.show(
                        context: context,
                        title: calendarName,
                        initialColor: effectiveColor,
                        onResetToDefault: hasCustom
                            ? () async {
                                if (cal.id != null) {
                                  await colorService.resetSubcalendarColor(cal.id!);
                                  if (context.mounted) {
                                    await taskProvider.updateHomeWidget();
                                  }
                                }
                              }
                            : null,
                        resetLabel: l10n.resetToGoogleDefault,
                        onColorChanged: (newColor) async {
                          if (cal.id != null) {
                            await colorService.setSubcalendarColor(cal.id!, newColor);
                            if (context.mounted) {
                              await taskProvider.updateHomeWidget();
                            }
                          }
                        },
                      );
                    },
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Color currentColor,
    required VoidCallback onTap,
    bool isCustom = false,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: currentColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: currentColor.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCustom)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Custom',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
