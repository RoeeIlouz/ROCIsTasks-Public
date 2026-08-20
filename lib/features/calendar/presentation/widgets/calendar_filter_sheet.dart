import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
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
                                return CheckboxListTile(
                                  title: Text(calendar.name ?? 'Unnamed'),
                                  subtitle: calendar.accountName != null
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
                                  secondary: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: calendar.color != null
                                          ? Color(calendar.color!)
                                          : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              }),
                            ],
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
