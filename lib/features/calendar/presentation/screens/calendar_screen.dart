import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_tile.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_skeleton.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/calendar/presentation/widgets/calendar_filter_sheet.dart';
import 'package:rocis_tasks/features/calendar/presentation/widgets/calendar_coloring_sheet.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

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

  Widget _buildCalendarCell(
    DateTime day, {
    bool isSelected = false,
    bool isToday = false,
    bool isOutside = false,
  }) {
    final theme = Theme.of(context);
    Color textColor = theme.colorScheme.onSurface;
    if (isOutside) {
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.3);
    } else {
      if (day.weekday == DateTime.sunday) {
        textColor = Colors.redAccent;
      } else if (day.weekday == DateTime.saturday) {
        textColor = Colors.blueAccent;
      }
    }

    if (isSelected) {
      textColor = theme.colorScheme.primary;
    } else if (isToday) {
      textColor = theme.colorScheme.primary;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isToday
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        border: isSelected
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: textColor,
              fontWeight: isSelected || isToday
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final calendarProvider = Provider.of<CalendarProvider>(context);
    final themeService = Provider.of<ThemeService>(context);
    final colorService = Provider.of<CalendarColorService>(context);
    final l10n = AppLocalizations.of(context)!;

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
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: GlassContainer(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, right: 4.0, bottom: 8.0, top: 4.0),
                  child: Row(
                    children: [
                      Text(
                        DateFormat.yMMMM().format(_focusedDay),
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.palette_outlined),
                        tooltip: l10n.calendarColors,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            constraints: const BoxConstraints(maxWidth: 500),
                            builder: (context) => const CalendarColoringSheet(),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.filter_alt_outlined),
                        tooltip: l10n.calendarFiltersTitle,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            constraints: const BoxConstraints(maxWidth: 500),
                            builder: (context) => const CalendarFilterSheet(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                TableCalendar(
                  headerVisible: false,
                  firstDay: DateTime(2020, 10, 16),
                  lastDay: DateTime(2030, 3, 14),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  daysOfWeekHeight: 24,
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
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                  eventLoader: (day) {
                    return _getEventsForDay(day, tasks, calendarProvider);
                  },
                  calendarBuilders: CalendarBuilders(
                    dowBuilder: (context, day) {
                      final text = DateFormat.E().format(day);
                      Color textColor = Theme.of(context).colorScheme.onSurface;
                      if (day.weekday == DateTime.sunday) {
                        textColor = Colors.redAccent;
                      } else if (day.weekday == DateTime.saturday) {
                        textColor = Colors.blueAccent;
                      }
                      return Center(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                    defaultBuilder: (context, day, focusedDay) =>
                        _buildCalendarCell(day),
                    todayBuilder: (context, day, focusedDay) =>
                        _buildCalendarCell(day, isToday: true),
                    selectedBuilder: (context, day, focusedDay) =>
                        _buildCalendarCell(day, isSelected: true),
                    outsideBuilder: (context, day, focusedDay) =>
                        _buildCalendarCell(day, isOutside: true),
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox.shrink();

                      if (events.length == 1) {
                        final event = events.first;
                        String title = '';
                        Color c = colorService.taskColor;
                        if (event is Task) {
                          title = event.title;
                          Category? category;
                          try {
                            category = taskProvider.categories.firstWhere(
                              (cat) => event.categoryIds.isNotEmpty
                                  ? event.categoryIds.contains(cat.id)
                                  : cat.id == event.categoryId,
                            );
                          } catch (_) {}
                          if (category != null) c = Color(category.colorValue);
                        } else if (event is Event) {
                          title = event.title ?? 'No Title';
                          final cal = calendarProvider.availableCalendars
                              .firstWhere(
                                (c) => c.id == event.calendarId,
                                orElse: Calendar.new,
                              );
                          c = cal.color != null
                              ? Color(cal.color!)
                              : colorService.googleColor;
                        }

                        return Positioned(
                          top: 25,
                          left: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: c.withValues(alpha: 0.25),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w600,
                                color: c,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final markers = <Widget>[];
                      for (final event in events.take(3)) {
                        Color c = colorService.taskColor;
                        if (event is Task) {
                          Category? category;
                          try {
                            category = taskProvider.categories.firstWhere(
                              (cat) => event.categoryIds.isNotEmpty
                                  ? event.categoryIds.contains(cat.id)
                                  : cat.id == event.categoryId,
                            );
                          } catch (_) {}
                          if (category != null) c = Color(category.colorValue);
                        } else if (event is Event) {
                          final cal = calendarProvider.availableCalendars
                              .firstWhere(
                                (c) => c.id == event.calendarId,
                                orElse: Calendar.new,
                              );
                          c = cal.color != null
                              ? Color(cal.color!)
                              : colorService.googleColor;
                        }
                        markers.add(
                          Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 1,
                              horizontal: 8,
                            ),
                            height: 4,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }

                      if (events.length > 3) {
                        markers.add(
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              '+${events.length - 3}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 8,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }

                      return Positioned(
                        top: 25,
                        left: 0,
                        right: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: markers,
                        ),
                      );
                    },
                  ),
                  calendarStyle: const CalendarStyle(
                    markersMaxCount: 0, // We handle markers ourselves
                    outsideDaysVisible: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: calendarProvider.isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: TaskListSkeleton(),
                )
              : selectedItems.isEmpty
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                    child: GlassContainer(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noEventsForThisDay,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: selectedItems.length,
                  padding: const EdgeInsets.only(bottom: 100),
                  itemBuilder: (context, index) {
                    final item = selectedItems[index];

                    if (item is Task) {
                      final List<String> categoryIds =
                          item.categoryIds.isNotEmpty
                          ? item.categoryIds
                          : (item.categoryId != null ? [item.categoryId!] : []);
                      final categories = categoryIds
                          .map(taskProvider.getCategoryById)
                          .where((c) => c != null)
                          .cast<Category>()
                          .toList();

                      return TaskTile(
                        task: item,
                        categories: categories,
                        enableSwipeToDelete: false,
                        enablePin: false,
                        onToggle: () => taskProvider.toggleTaskCompletion(item),
                        onDelete: () => taskProvider.deleteTask(item.id),
                      );
                    } else if (item is Event) {
                      final timeFormat = themeService.use24HourFormat
                          ? DateFormat.Hm()
                          : DateFormat.jm();
                      final cal = calendarProvider.availableCalendars
                          .firstWhere(
                            (c) => c.id == item.calendarId,
                            orElse: Calendar.new,
                          );
                      final googleColor = cal.color != null
                          ? Color(cal.color!)
                          : colorService.googleColor;
                      return GlassContainer(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        selectedBorderColor: googleColor,
                        isSelected: false,
                        child: Semantics(
                          label:
                              'Google Calendar Event: ${item.title ?? 'No Title'}',
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
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: googleColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Google',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: googleColor,
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
