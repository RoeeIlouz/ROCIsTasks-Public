import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/app_color_picker_sheet.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class CalendarFilterSheet extends StatelessWidget {
  const CalendarFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<CalendarProvider>(
      builder: (context, provider, child) {
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.35,
          maxChildSize: 0.7,
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
                    l10n.calendarFiltersTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  GlassContainer(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(l10n.showCalendarTasks),
                          value: provider.showTasks,
                          onChanged: (value) {
                            provider.updateFilters(showTasks: value);
                          },
                          secondary: const Icon(Icons.task_alt_rounded),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: Text(l10n.showGoogleCalendar),
                          value: provider.showGoogleCalendar,
                          onChanged: (value) {
                            provider.updateFilters(showGoogleCalendar: value);
                          },
                          secondary: const Icon(Icons.event_note_rounded),
                        ),
                        if (provider.isGoogleCalendarTokenExpired) ...[
                          const Divider(height: 1),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 10.0,
                            ),
                            color: Colors.amber.withValues(alpha: 0.1),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.googleTasksDisconnected,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final authService =
                                        Provider.of<AuthService>(
                                          context,
                                          listen: false,
                                        );
                                    final success = await authService
                                        .linkGoogleTasks();
                                    if (success) {
                                      provider.resetTokenExpiredState();
                                      await provider.loadEvents();
                                    }
                                  },
                                  child: Text(l10n.reconnect),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (provider.showGoogleCalendar &&
                            provider.availableCalendars.isNotEmpty) ...[
                          const Divider(height: 1),
                          ExpansionTile(
                            title: Text(l10n.selectGoogleCalendars),
                            leading: const Icon(
                              Icons.calendar_view_day_rounded,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          provider.setAllCalendars(true),
                                      child: Text(l10n.selectAll),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          provider.setAllCalendars(false),
                                      child: Text(l10n.deselectAll),
                                    ),
                                  ],
                                ),
                              ),
                              ...provider.availableCalendars.map((calendar) {
                                final isSelected = provider.selectedCalendarIds
                                    .contains(calendar.id);
                                final calendarName =
                                    (calendar.name != null &&
                                        calendar.name!.trim().isNotEmpty &&
                                        calendar.name!.toLowerCase() !=
                                            'unnamed' &&
                                        calendar.name!.toLowerCase() !=
                                            'unnamed calendar')
                                    ? calendar.name!
                                    : (calendar.accountName
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? calendar.accountName!
                                          : l10n.calendar);
                                final hasSubtitle =
                                    calendar.accountName != null &&
                                    calendar.accountName!.trim().isNotEmpty &&
                                    calendar.accountName != calendarName;
                                final colorService =
                                    Provider.of<CalendarColorService>(context);
                                final taskProvider = Provider.of<TaskProvider>(
                                  context,
                                  listen: false,
                                );
                                final Color? nativeColor =
                                    calendar.color != null
                                    ? Color(calendar.color!)
                                    : null;
                                final Color effectiveColor = colorService
                                    .getEffectiveSubcalendarColor(
                                      calendar.id,
                                      nativeColor: nativeColor,
                                    );
                                final bool hasCustom =
                                    calendar.id != null &&
                                    colorService.hasCustomSubcalendarColor(
                                      calendar.id!,
                                    );

                                return CheckboxListTile(
                                  title: Text(calendarName),
                                  subtitle: hasSubtitle
                                      ? Text(calendar.accountName!)
                                      : null,
                                  value: isSelected,
                                  onChanged: (_) {
                                    if (calendar.id != null) {
                                      provider.toggleCalendarSelection(
                                        calendar.id!,
                                      );
                                    }
                                  },
                                  secondary: GestureDetector(
                                    onTap: () {
                                      AppColorPickerSheet.show(
                                        context: context,
                                        title: calendarName,
                                        initialColor: effectiveColor,
                                        onResetToDefault: hasCustom
                                            ? () async {
                                                if (calendar.id != null) {
                                                  await colorService
                                                      .resetSubcalendarColor(
                                                        calendar.id!,
                                                      );
                                                  if (context.mounted) {
                                                    await taskProvider
                                                        .updateHomeWidget();
                                                  }
                                                }
                                              }
                                            : null,
                                        resetLabel: l10n.resetToGoogleDefault,
                                        onColorChanged: (newColor) async {
                                          if (calendar.id != null) {
                                            await colorService
                                                .setSubcalendarColor(
                                                  calendar.id!,
                                                  newColor,
                                                );
                                            if (context.mounted) {
                                              await taskProvider
                                                  .updateHomeWidget();
                                            }
                                          }
                                        },
                                      );
                                    },
                                    child: Semantics(
                                      label:
                                          '${l10n.customColor}: $calendarName',
                                      button: true,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: effectiveColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline
                                                .withValues(alpha: 0.3),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: effectiveColor.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: hasCustom
                                            ? Icon(
                                                Icons.palette_rounded,
                                                size: 11,
                                                color:
                                                    effectiveColor
                                                            .computeLuminance() >
                                                        0.5
                                                    ? Colors.black87
                                                    : Colors.white,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                        if (provider.showGoogleCalendar &&
                            provider.availableCalendars.isEmpty) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'No calendars loaded',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    provider.requestPermissionsAndReload();
                                  },
                                  child: const Text('Sync Calendars'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
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
}
