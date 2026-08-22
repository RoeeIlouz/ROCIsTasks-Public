import 'package:device_calendar/device_calendar.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rocis_tasks/core/services/auth_service.dart';

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  AuthService? _authService;

  void setAuthService(AuthService authService) {
    _authService = authService;
  }

  Future<void> init() async {
    // Permissions will be requested when needed (e.g. entering calendar view)
    // or when loading events, to avoid blocking app startup.
  }

  /// Safely converts a [DateTime] to [tz.TZDateTime] without crashing if
  /// timezones are uninitialized on Web.
  tz.TZDateTime _toTZDateTime(DateTime dt) {
    try {
      return tz.TZDateTime.from(dt.toUtc(), tz.local);
    } catch (_) {
      final localDt = dt.toLocal();
      try {
        return tz.TZDateTime.from(localDt, tz.local);
      } catch (_) {
        return tz.TZDateTime(
          tz.local,
          localDt.year,
          localDt.month,
          localDt.day,
          localDt.hour,
          localDt.minute,
          localDt.second,
        );
      }
    }
  }

  /// Centralized Web token resolution that returns null if no token is cached.
  Future<String?> _getWebAccessToken() async {
    if (_authService != null) {
      final token = await _authService!.getGoogleAccessToken();
      if (token != null) return token;
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('google_access_token');
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
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
    if (kIsWeb) {
      try {
        final token = await _getWebAccessToken();
        if (token == null || token.isEmpty) {
          throw GoogleTokenExpiredException(
            'No Web Google access token available.',
            true,
          );
        }

        final uri = Uri.https(
          'www.googleapis.com',
          '/calendar/v3/users/me/calendarList',
        );

        final response = await http.get(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 401) {
          AppLogger.warning(
            'Google Calendar list API returned 401 (Unauthorized).',
            tag: 'Calendar',
          );
          throw GoogleTokenExpiredException(
            'Google Calendar token rejected by server (401).',
            true,
          );
        }

        if (response.statusCode == 403) {
          AppLogger.warning(
            'Google Calendar list API returned 403. Falling back to primary calendar.',
            tag: 'Calendar',
          );
          return [
            Calendar(
              id: 'primary',
              name: 'Google Calendar',
              isDefault: true,
              color: 0xFF6366F1,
            ),
          ];
        }

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = data['items'] as List<dynamic>? ?? [];

          final List<Calendar> calendars = [];
          for (final item in items) {
            final id = item['id'] as String?;
            if (id == null) continue;
            if (item['deleted'] == true || item['hidden'] == true) continue;

            final name = item['summary'] as String? ?? 'Unnamed Calendar';
            final accessRole = item['accessRole'] as String?;
            final isReadOnly =
                accessRole == 'reader' || accessRole == 'freeBusyReader';

            final bgHex = item['backgroundColor'] as String? ?? '#6366F1';
            int colorVal = 0xFF6366F1;
            try {
              final hex = bgHex.replaceAll('#', '');
              colorVal = int.parse('FF$hex', radix: 16);
            } catch (_) {}

            calendars.add(
              Calendar(
                id: id,
                name: name,
                isReadOnly: isReadOnly,
                isDefault: item['primary'] == true,
                color: colorVal,
              ),
            );
          }

          if (calendars.isEmpty) {
            calendars.add(
              Calendar(
                id: 'primary',
                name: 'Google Calendar',
                isDefault: true,
                color: 0xFF6366F1,
              ),
            );
          }
          return calendars;
        } else {
          AppLogger.error(
            'Google Calendar list API failed on Web. Status: ${response.statusCode}, Body: ${response.body}',
            tag: 'Calendar',
          );
        }
      } on GoogleTokenExpiredException {
        rethrow;
      } catch (e, s) {
        AppLogger.error(
          'Error retrieving calendars on Web',
          error: e,
          stack: s,
        );
      }
      return [];
    }

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
        colorMap[calendar.id!] =
            '#${calendar.color!.toUnsigned(32).toRadixString(16).padLeft(8, '0')}';
      }
    }
    return colorMap;
  }

  Future<List<Event>> getEvents({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? calendarIds,
  }) async {
    if (kIsWeb) {
      try {
        final token = await _getWebAccessToken();
        if (token == null || token.isEmpty) {
          throw GoogleTokenExpiredException(
            'No Web Google access token available.',
            true,
          );
        }

        final now = DateTime.now();
        final start = startDate ?? now.subtract(const Duration(days: 365));
        final end = endDate ?? now.add(const Duration(days: 365));
        final List<Event> allEvents = [];

        List<String> targetCalendarIds = calendarIds ?? [];
        if (targetCalendarIds.isEmpty) {
          final cals = await getAvailableCalendars();
          targetCalendarIds = cals.map((c) => c.id).whereType<String>().toList();
        }
        if (targetCalendarIds.isEmpty) {
          targetCalendarIds = ['primary'];
        }

        int failedSecondaryCalendars = 0;

        for (final calendarId in targetCalendarIds) {
          try {
            final queryParams = {
              'timeMin': start.toUtc().toIso8601String(),
              'timeMax': end.toUtc().toIso8601String(),
              'singleEvents': 'true',
              'orderBy': 'startTime',
            };

            final uri = Uri.https(
              'www.googleapis.com',
              '/calendar/v3/calendars/$calendarId/events',
              queryParams,
            );

            final response = await http.get(
              uri,
              headers: {'Authorization': 'Bearer $token'},
            );

            if (response.statusCode == 401) {
              AppLogger.warning(
                'Google Calendar API request returned 401 for $calendarId: ${response.body}',
                tag: 'Calendar',
              );
              throw GoogleTokenExpiredException(
                'Google Calendar token rejected by server (401).',
                true,
              );
            }

            if (response.statusCode == 403 || response.statusCode == 404) {
              AppLogger.warning(
                'Google Calendar API request returned ${response.statusCode} for calendar $calendarId. Skipping secondary calendar.',
                tag: 'Calendar',
              );
              failedSecondaryCalendars++;
              // Only throw if the primary/only calendar failed with 403 and no events fetched
              if (calendarId == 'primary' && targetCalendarIds.length == 1 && allEvents.isEmpty) {
                throw GoogleTokenExpiredException(
                  'Primary Google Calendar token rejected by server (403).',
                  true,
                );
              }
              continue;
            }

            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final items = data['items'] as List<dynamic>? ?? [];

              for (final item in items) {
                if (item['status'] == 'cancelled') continue;

                final id = item['id'] as String?;
                final title = item['summary'] as String? ?? 'No Title';
                final desc = item['description'] as String?;

                final startData = item['start'] as Map<String, dynamic>?;
                final endData = item['end'] as Map<String, dynamic>?;

                if (startData == null) continue;

                DateTime? startTime;
                DateTime? endTime;
                bool allDay = false;

                if (startData.containsKey('dateTime')) {
                  startTime =
                      DateTime.parse(startData['dateTime'] as String).toLocal();
                } else if (startData.containsKey('date')) {
                  final dateStr = startData['date'] as String;
                  final parts = dateStr.split('-');
                  if (parts.length == 3) {
                    startTime = DateTime(
                      int.parse(parts[0]),
                      int.parse(parts[1]),
                      int.parse(parts[2]),
                    );
                  } else {
                    startTime = DateTime.parse(dateStr).toLocal();
                  }
                  allDay = true;
                }

                if (endData != null) {
                  if (endData.containsKey('dateTime')) {
                    endTime =
                        DateTime.parse(endData['dateTime'] as String).toLocal();
                  } else if (endData.containsKey('date')) {
                    final dateStr = endData['date'] as String;
                    final parts = dateStr.split('-');
                    if (parts.length == 3) {
                      endTime = DateTime(
                        int.parse(parts[0]),
                        int.parse(parts[1]),
                        int.parse(parts[2]),
                      );
                    } else {
                      endTime = DateTime.parse(dateStr).toLocal();
                    }
                  }
                }

                if (startTime == null) continue;
                endTime ??= startTime.add(const Duration(hours: 1));

                allEvents.add(
                  Event(
                    calendarId,
                    eventId: id,
                    title: title,
                    description: desc,
                    start: _toTZDateTime(startTime),
                    end: _toTZDateTime(endTime),
                    allDay: allDay,
                  ),
                );
              }
            } else {
              AppLogger.error(
                'Google Calendar events API failed for $calendarId. Status: ${response.statusCode}, Body: ${response.body}',
                tag: 'Calendar',
              );
            }
          } catch (e) {
            if (e is GoogleTokenExpiredException) {
              rethrow;
            }
            AppLogger.error(
              'Error fetching events for calendar $calendarId on Web',
              error: e,
            );
          }
        }

        if (allEvents.isEmpty && failedSecondaryCalendars == targetCalendarIds.length && targetCalendarIds.isNotEmpty) {
          AppLogger.warning('All targeted calendars failed with 403/404 on Web.', tag: 'Calendar');
        }

        return allEvents;
      } on GoogleTokenExpiredException {
        rethrow;
      } catch (e, s) {
        AppLogger.error(
          'Error fetching Google Calendar events on Web',
          error: e,
          stack: s,
        );
      }
      return [];
    }

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
    final writableCalendars = calendars
        .where((c) => c.isReadOnly != true)
        .toList();
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
    if (kIsWeb) {
      try {
        final token = await _getWebAccessToken();

        final body = {
          'summary': title,
          'description': description ?? '',
          'start': {'dateTime': start.toUtc().toIso8601String()},
          'end': {'dateTime': end.toUtc().toIso8601String()},
        };

        final headers = {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };

        http.Response response;
        if (eventId != null) {
          final uri = Uri.https(
            'www.googleapis.com',
            '/calendar/v3/calendars/$calendarId/events/$eventId',
          );
          response = await http.put(
            uri,
            headers: headers,
            body: json.encode(body),
          );
        } else {
          final uri = Uri.https(
            'www.googleapis.com',
            '/calendar/v3/calendars/$calendarId/events',
          );
          response = await http.post(
            uri,
            headers: headers,
            body: json.encode(body),
          );
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          throw GoogleTokenExpiredException(
            'Google Calendar token rejected by server.',
            true,
          );
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          return data['id'] as String?;
        }
      } on GoogleTokenExpiredException {
        rethrow;
      } catch (e, s) {
        AppLogger.error(
          'Error creating/updating calendar event on Web',
          error: e,
          stack: s,
        );
      }
      return null;
    }

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
      AppLogger.error(
        'Error creating/updating calendar event',
        error: e,
        stack: s,
      );
    }

    return null;
  }

  Future<bool> deleteEvent({
    required String calendarId,
    required String eventId,
  }) async {
    if (kIsWeb) {
      try {
        final token = await _getWebAccessToken();

        final uri = Uri.https(
          'www.googleapis.com',
          '/calendar/v3/calendars/$calendarId/events/$eventId',
        );

        final response = await http.delete(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 401 || response.statusCode == 403) {
          throw GoogleTokenExpiredException(
            'Google Calendar token rejected by server.',
            true,
          );
        }

        if (response.statusCode == 200 || response.statusCode == 204) {
          return true;
        }
      } on GoogleTokenExpiredException {
        rethrow;
      } catch (e, s) {
        AppLogger.error(
          'Error deleting calendar event on Web',
          error: e,
          stack: s,
        );
      }
      return false;
    }

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
