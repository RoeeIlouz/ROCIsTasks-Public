import 'package:flutter/foundation.dart';
import 'package:device_calendar/device_calendar.dart';

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
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  Future<List<Event>> getEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('Calendar permissions not granted');
      return [];
    }

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365));
    final end = endDate ?? now.add(const Duration(days: 365));
    final allEvents = <Event>[];

    try {
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();

      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        for (var calendar in calendarsResult.data!) {
          try {
            final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
              calendar.id,
              RetrieveEventsParams(startDate: start, endDate: end),
            );
            if (eventsResult.isSuccess && eventsResult.data != null) {
              allEvents.addAll(eventsResult.data!);
            }
          } catch (e) {
            debugPrint('Error accessing calendar ${calendar.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Calendar retrieval error: $e');
    }

    return allEvents;
  }
}
