import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';

/// ROCIs Schedule classes for the in-app calendar and every widget.
///
/// Reads the schedule itself. When that yields nothing (not connected, or
/// offline with no cache), falls back to the copies ROCIs Schedule exported to
/// Google Calendar, so classes still show as schedule events. Never throws.
Future<List<SyncedScheduleEvent>> loadScheduleEvents({
  required ScheduleFirestoreService scheduleService,
  required CalendarService calendarService,
  String? uid,
  String? email,
  bool forceRefresh = false,
  DateTime? startDate,
  DateTime? endDate,
}) async {
  try {
    final events = await scheduleService.fetchEvents(
      uid: uid,
      email: email,
      forceRefresh: forceRefresh,
    );
    if (events.isNotEmpty) return events;
  } catch (e) {
    AppLogger.warning('Could not fetch ROCIs Schedule events: $e');
  }
  return calendarService.getExportedScheduleEvents(
    startDate: startDate,
    endDate: endDate,
  );
}
