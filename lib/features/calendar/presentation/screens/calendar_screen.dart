import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_tile.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';

import 'package:rocis_tasks/shared/ui/ui_kit.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<CalendarProvider>(context, listen: false);
    _focusedDay = provider.selectedDate;

    // Reload events when entering the screen to ensure we have the latest data
    // and to retry if permissions were previously denied
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Set user ID and email for schedule data fetching (must be done after build to avoid setState during build)
      final authService = Provider.of<AuthService>(context, listen: false);
      provider.setUserId(authService.currentUser?.uid);
      provider.setUserEmail(authService.currentUser?.email);
      provider.loadFilters();
      provider.loadEvents();
    });
  }

  List<dynamic> _getEventsForDay(
    DateTime day,
    List<Task> allTasks,
    CalendarProvider
    calendarProvider, // Changed to use provider directly for optimized lookup
  ) {
    final tasks = calendarProvider.showTasks
        ? allTasks.where((task) {
            if (task.dueDate == null) return false;
            return isSameDay(task.dueDate, day);
          }).toList()
        : <Task>[];

    final events = calendarProvider.getEventsForDay(day);

    return [...tasks, ...events];
  }

  Widget _buildMarker(Color color) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 0.5),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final calendarProvider = Provider.of<CalendarProvider>(context);
    final themeService = Provider.of<ThemeService>(context);
    final colorService = Provider.of<CalendarColorService>(context);

    final tasks = taskProvider.tasks;
    // events list not needed here as we query provider by day
    final selectedDay = calendarProvider.selectedDate;

    final selectedItems = _getEventsForDay(
      selectedDay,
      tasks,
      calendarProvider,
    );

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime(2020, 10, 16),
          lastDay: DateTime(2030, 3, 14),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) {
            return isSameDay(selectedDay, day);
          },
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(calendarProvider.selectedDate, selectedDay)) {
              calendarProvider.setSelectedDate(selectedDay);
              setState(() {
                _focusedDay = focusedDay;
              });
            }
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          eventLoader: (day) {
            return _getEventsForDay(day, tasks, calendarProvider);
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return const SizedBox.shrink();
              
              // Group events by type and get colors
              final markers = <Widget>[];
              bool hasTask = false;
              bool hasGoogleEvent = false;
              bool hasScheduleEvent = false;
              bool hasAssignment = false;
              
              for (final event in events) {
                if (event is Task && !hasTask) {
                  hasTask = true;
                  // Task marker - custom color or category color
                  Category? category;
                  try {
                    category = taskProvider.categories.firstWhere(
                      (c) => c.id == event.categoryId,
                    );
                  } catch (_) {}
                  markers.add(_buildMarker(
                    category != null ? Color(category.colorValue) : colorService.taskColor,
                  ));
                } else if (event is Event && !hasGoogleEvent) {
                  hasGoogleEvent = true;
                  // Google Calendar marker - custom color
                  markers.add(_buildMarker(colorService.googleColor));
                } else if (event is ScheduleEventWrapper && !hasScheduleEvent) {
                  hasScheduleEvent = true;
                  // ROCIs Schedule event marker - custom color
                  markers.add(_buildMarker(colorService.scheduleColor));
                } else if (event is AssignmentWrapper && !hasAssignment) {
                  hasAssignment = true;
                  // Assignment marker - custom color
                  markers.add(_buildMarker(colorService.assignmentColor));
                }
              }
              
              // Limit to 4 markers max
              final displayMarkers = markers.take(4).toList();
              
              return Positioned(
                bottom: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: displayMarkers,
                ),
              );
            },
          ),
          calendarStyle: CalendarStyle(
            markersMaxCount: 0, // We handle markers ourselves
            todayDecoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: ListView.builder(
            itemCount: selectedItems.length,
            itemBuilder: (context, index) {
              final item = selectedItems[index];

              if (item is Task) {
                Category? category;
                try {
                  category = taskProvider.categories.firstWhere(
                    (c) => c.id == item.categoryId,
                  );
                } catch (_) {
                  category = null;
                }

                return TaskTile(
                  task: item,
                  category: category,
                  enableSwipeToDelete: false,
                  enablePin: false,
                  onToggle: () => taskProvider.toggleTaskCompletion(item),
                  onDelete: () => taskProvider.deleteTask(item.id),
                );
              } else if (item is Event) {
                final timeFormat = themeService.use24HourFormat
                    ? DateFormat.Hm()
                    : DateFormat.jm();
                final googleColor = colorService.googleColor;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: googleColor.withValues(alpha: 0.5),
                    ),
                  ),
                  color: Theme.of(context).colorScheme.surface,
                  child: Semantics(
                    label: 'Google Calendar Event: ${item.title ?? 'No Title'}',
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: googleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.event_note_rounded,
                          color: googleColor,
                          size: 24,
                        ),
                      ),
                    title: Text(
                      item.title ?? 'No Title',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.start != null ? timeFormat.format(item.start!) : ''} - '
                            '${item.end != null ? timeFormat.format(item.end!) : ''}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: googleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Google',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: googleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            } else if (item is ScheduleEventWrapper) {
                // ROCIs-Schedule event (class, exam, lab, etc.)
                final timeFormat = themeService.use24HourFormat
                    ? DateFormat.Hm()
                    : DateFormat.jm();
                final eventColor = colorService.scheduleColor;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: eventColor.withValues(alpha: 0.5),
                    ),
                  ),
                  color: Theme.of(context).colorScheme.surface,
                  child: Semantics(
                    label: '${item.eventType}: ${item.title}',
                    hint: item.location.isNotEmpty ? 'Location: ${item.location}' : null,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: eventColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          color: eventColor,
                          size: 24,
                        ),
                      ),
                    title: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${timeFormat.format(item.start)} - ${timeFormat.format(item.end)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (item.location.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.location,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: eventColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.eventType,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: eventColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            } else if (item is AssignmentWrapper) {
                // ROCIs-Schedule assignment
                final assignmentColor = colorService.assignmentColor;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: assignmentColor.withValues(alpha: 0.5),
                    ),
                  ),
                  color: Theme.of(context).colorScheme.surface,
                  child: Semantics(
                    label: 'Assignment: ${item.title}',
                    hint: item.description.isNotEmpty ? item.description : null,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: assignmentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.assignment_rounded,
                          color: assignmentColor,
                          size: 24,
                        ),
                      ),
                    title: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    subtitle: item.description.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : null,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: assignmentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Due',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: assignmentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox();
            },
          ),
        ),
      ],
    );
  }
}
