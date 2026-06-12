import 'package:device_calendar/device_calendar.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:timezone/timezone.dart' as tz;

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  Future<void> init() async {
    // Permissions will be requested when needed (e.g. entering calendar view)
    // or when loading events, to avoid blocking app startup.
  }

  Future<bool> requestPermissions() async {
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && permissionsGranted.data!) {
        return true;
      }

      permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      return permissionsGranted.isSuccess && permissionsGranted.data!;
    } catch (e, s) {
      AppLogger.error(
        'Error requesting calendar permissions',
        error: e,
        stack: s,
      );
      return false;
    }
  }

  Future<List<Calendar>> getAvailableCalendars() async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return [];

    try {
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        return calendarsResult.data!;
      }
    } catch (e, s) {
      AppLogger.error('Error retrieving calendars', error: e, stack: s);
    }
    return [];
  }

  Future<Map<String, String>> getCalendarColors() async {
    final calendars = await getAvailableCalendars();
    final Map<String, String> colorMap = {};
    for (final calendar in calendars) {
      if (calendar.id != null && calendar.color != null) {
        colorMap[calendar.id!] = '#${calendar.color!.toRadixString(16).padLeft(8, '0')}';
      }
    }
    return colorMap;
  }

  Future<List<Event>> getEvents({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? calendarIds,
  }) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      AppLogger.warning('Calendar permissions not granted');
      return [];
    }

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365));
    final end = endDate ?? now.add(const Duration(days: 365));
    final allEvents = <Event>[];

    try {
      if (calendarIds != null && calendarIds.isNotEmpty) {
        // Fetch only from specified calendars
        for (final calendarId in calendarIds) {
          try {
            final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
              calendarId,
              RetrieveEventsParams(startDate: start, endDate: end),
            );
            if (eventsResult.isSuccess && eventsResult.data != null) {
              allEvents.addAll(eventsResult.data!);
            }
          } catch (e, s) {
            AppLogger.error(
              'Error accessing calendar $calendarId',
              error: e,
              stack: s,
            );
          }
        }
      } else {
        // Fetch from all calendars
        final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();

        if (calendarsResult.isSuccess && calendarsResult.data != null) {
          for (final calendar in calendarsResult.data!) {
            try {
              final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
                calendar.id,
                RetrieveEventsParams(startDate: start, endDate: end),
              );
              if (eventsResult.isSuccess && eventsResult.data != null) {
                allEvents.addAll(eventsResult.data!);
              }
            } catch (e, s) {
              AppLogger.error(
                'Error accessing calendar ${calendar.id}',
                error: e,
                stack: s,
              );
            }
          }
        }
      }
    } catch (e, s) {
      AppLogger.error('Calendar retrieval error', error: e, stack: s);
    }

    return allEvents;
  }

  Future<Calendar?> getDefaultWritableCalendar() async {
    final calendars = await getAvailableCalendars();
    final writableCalendars = calendars.where((c) => c.isReadOnly != true).toList();
    if (writableCalendars.isEmpty) return null;
    return writableCalendars.first;
  }

  Future<String?> createOrUpdateTaskEvent({
    required String calendarId,
    required String title,
    String? description,
    required DateTime start,
    required DateTime end,
    String? eventId,
  }) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      AppLogger.warning('Calendar permissions not granted');
      return null;
    }

    try {
      final tzStart = tz.TZDateTime.from(start, tz.local);
      final tzEnd = tz.TZDateTime.from(end, tz.local);

      final event = Event(
        calendarId,
        eventId: eventId,
        title: title,
        description: description,
        start: tzStart,
        end: tzEnd,
      );

      final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true) {
        return result!.data;
      }
    } catch (e, s) {
      AppLogger.error('Error creating/updating calendar event', error: e, stack: s);
    }

    return null;
  }

  Future<bool> deleteEvent({
    required String calendarId,
    required String eventId,
  }) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      AppLogger.warning('Calendar permissions not granted');
      return false;
    }

    try {
      final result = await _deviceCalendarPlugin.deleteEvent(
        calendarId,
        eventId,
      );
      return result.isSuccess && (result.data ?? false);
    } catch (e, s) {
      AppLogger.error('Error deleting calendar event', error: e, stack: s);
      return false;
    }
  }
}
