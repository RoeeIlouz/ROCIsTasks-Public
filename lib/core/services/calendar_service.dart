import 'package:device_calendar/device_calendar.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/auth/google_oauth_manager.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  AuthService? _authService;
  static const String _keyCachedEvents = 'cached_calendar_events_v2';
  List<Calendar>? _cachedCalendars;
  DateTime? _cachedCalendarsTime;
  static const Duration _calendarCacheTtl = Duration(minutes: 5);

  CalendarService({AuthService? authService}) : _authService = authService;

  void setAuthService(AuthService authService) {
    _authService = authService;
  }

  void invalidateCalendarsCache() {
    _cachedCalendars = null;
    _cachedCalendarsTime = null;
  }

  Future<void> init() async {
    // Permissions will be requested when needed (e.g. entering calendar view)
    // or when loading events, to avoid blocking app startup.
  }

  /// Safely converts a [DateTime] to [tz.TZDateTime] without crashing if
  /// timezones are uninitialized on Web.
  tz.TZDateTime _toTZDateTime(DateTime dt) {
    try {
      return tz.TZDateTime.from(dt, tz.local);
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

  /// Centralized token resolution that supports background isolates and silent refresh.
  Future<String?> _getAccessToken() async {
    if (_authService != null) {
      final isGoogleUser =
          _authService!.currentUser?.providerData.any(
            (p) => p.providerId == 'google.com',
          ) ??
          false;
      if (isGoogleUser) {
        final token = await _authService!.getGoogleAccessToken();
        if (token != null && token.isNotEmpty) return token;
      }
    }

    // Background isolate fallback: read directly from SharedPreferences or attempt silent refresh
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('google_access_token');
      final expiresAtStr = prefs.getString('google_access_token_expires_at');
      if (token != null && token.isNotEmpty) {
        if (expiresAtStr != null) {
          final expiresAt = DateTime.tryParse(expiresAtStr);
          if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {
            return token;
          }
        } else {
          return token;
        }
      }

      // Proactive silent refresh using GoogleOAuthManager
      final oauthManager = GoogleOAuthManager(ErrorHandlingService());
      final freshToken = await oauthManager.getGoogleAccessToken();
      if (freshToken != null && freshToken.isNotEmpty) {
        return freshToken;
      }

      // If silent refresh failed (e.g. network cutoff in doze), fall back to cached token
      if (token != null && token.isNotEmpty) {
        return token;
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to resolve Google access token in background: $e',
      );
    }
    return null;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && permissionsGranted.data == true) {
        return true;
      }

      permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      return permissionsGranted.isSuccess && permissionsGranted.data == true;
    } catch (e, s) {
      AppLogger.error(
        'Error requesting calendar permissions',
        error: e,
        stack: s,
      );
      return false;
    }
  }

  Future<List<Calendar>> getAvailableCalendars({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedCalendars != null &&
        _cachedCalendarsTime != null &&
        DateTime.now().difference(_cachedCalendarsTime!) < _calendarCacheTtl) {
      return _cachedCalendars!;
    }

    final List<Calendar> rawCalendars = [];
    final token = await _getAccessToken();

    // 1. On Mobile, prioritize native device calendars (which includes OS-synced Google calendars)
    if (!kIsWeb) {
      try {
        final hasPermission = await requestPermissions();
        if (hasPermission) {
          final calendarsResult = await _deviceCalendarPlugin
              .retrieveCalendars();
          if (calendarsResult.isSuccess && calendarsResult.data != null) {
            rawCalendars.addAll(calendarsResult.data!);
          }
        }
      } catch (e, s) {
        AppLogger.error(
          'Error retrieving device calendars',
          error: e,
          stack: s,
        );
      }
    }

    // 2. Query Google Calendar REST API whenever authenticated
    final List<Calendar> googleApiCalendars = [];
    if (token != null && token.isNotEmpty) {
      try {
        final uri = Uri.https(
          'www.googleapis.com',
          '/calendar/v3/users/me/calendarList',
        );

        final response = await http
            .get(uri, headers: {'Authorization': 'Bearer $token'})
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 401 || response.statusCode == 403) {
          AppLogger.warning(
            'Google Calendar list API returned ${response.statusCode} (Unauthorized/Forbidden).',
            tag: 'Calendar',
          );
          await _authService?.handleTokenRevokedOrExpired();
          throw GoogleTokenExpiredException(
            'Google Calendar token rejected by server (${response.statusCode}).',
            true,
          );
        } else if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = data['items'] as List<dynamic>? ?? [];

          for (final item in items) {
            final id = item['id'] as String?;
            if (id == null || id.trim().isEmpty) continue;
            if (item['deleted'] == true || item['hidden'] == true) continue;

            final summaryOverride = (item['summaryOverride'] as String?)
                ?.trim();
            final summary = (item['summary'] as String?)?.trim();
            final description = (item['description'] as String?)?.trim();
            final isPrimary = item['primary'] == true;

            String? name;
            if (summaryOverride != null && summaryOverride.isNotEmpty) {
              name = summaryOverride;
            } else if (summary != null && summary.isNotEmpty) {
              name = summary;
            } else if (description != null && description.isNotEmpty) {
              name = description;
            } else if (isPrimary || id.contains('@')) {
              name = id;
            }

            final accessRole = item['accessRole'] as String?;
            final isReadOnly =
                accessRole == 'reader' || accessRole == 'freeBusyReader';

            final bgHex = item['backgroundColor'] as String? ?? '#6366F1';
            int colorVal = 0xFF6366F1;
            try {
              final hex = bgHex.replaceAll('#', '');
              colorVal = int.parse('FF$hex', radix: 16);
            } catch (_) {}

            googleApiCalendars.add(
              Calendar(
                id: id,
                name: name,
                accountName: isPrimary ? id : (id.contains('@') ? id : null),
                accountType: 'com.google',
                isReadOnly: isReadOnly,
                isDefault: isPrimary,
                color: colorVal,
              ),
            );
          }
        }
      } on GoogleTokenExpiredException {
        if (kIsWeb) rethrow;
      } catch (e, s) {
        AppLogger.error(
          'Error retrieving Google Calendars via API',
          error: e,
          stack: s,
        );
      }
    } else if (kIsWeb) {
      final isGoogle =
          _authService?.currentUser?.providerData.any(
            (p) => p.providerId == 'google.com',
          ) ??
          false;
      if (isGoogle) {
        throw GoogleTokenExpiredException(
          'No Web Google access token available.',
          true,
        );
      }
    }

    final List<Calendar> combined = [];
    if (googleApiCalendars.isNotEmpty) {
      // Find the primary Google email if present
      String? primaryEmail;
      for (final c in googleApiCalendars) {
        if (c.isDefault == true ||
            (c.id != null &&
                c.id!.contains('@') &&
                !c.id!.contains('group.calendar.google.com'))) {
          primaryEmail = c.id?.toLowerCase();
          break;
        }
      }

      // Filter out device calendars that match the authenticated Google account to prevent duplicates
      for (final devCal in rawCalendars) {
        final acc = devCal.accountName?.toLowerCase();
        final type = devCal.accountType?.toLowerCase();
        final isAuthGoogle =
            (type == 'com.google' &&
                (primaryEmail == null || acc == primaryEmail)) ||
            (primaryEmail != null && acc == primaryEmail);
        if (!isAuthGoogle) {
          combined.add(devCal);
        }
      }
      combined.addAll(googleApiCalendars);
    } else {
      combined.addAll(rawCalendars);
    }

    final calendars = _sanitizeAndFilterCalendars(combined);

    if (calendars.isEmpty && (kIsWeb || (token != null && token.isNotEmpty))) {
      calendars.add(
        Calendar(
          id: 'primary',
          name: 'Google Calendar',
          isDefault: true,
          color: 0xFF6366F1,
          accountType: 'com.google',
        ),
      );
    }
    _cachedCalendars = calendars;
    _cachedCalendarsTime = DateTime.now();
    return calendars;
  }

  /// Sanitizes calendar entries by resolving friendly names, removing corrupt/empty
  /// ghost rows without identity, and deduplicating by ID.
  List<Calendar> _sanitizeAndFilterCalendars(List<Calendar> rawCalendars) {
    final Map<String, Calendar> uniqueCalendars = {};

    for (final calendar in rawCalendars) {
      final id = calendar.id?.trim();
      if (id == null || id.isEmpty) continue;

      var name = calendar.name?.trim();
      final accountName = calendar.accountName?.trim();

      final isNameInvalid =
          name == null ||
          name.isEmpty ||
          name.toLowerCase() == 'unnamed' ||
          name.toLowerCase() == 'unnamed calendar';

      final isAccountInvalid = accountName == null || accountName.isEmpty;

      // If both name and account are empty/invalid, it is a ghost row. Skip it.
      if (isNameInvalid && isAccountInvalid) {
        continue;
      }

      // If name is missing or generic "Unnamed", fallback to accountName or clean name
      if (isNameInvalid && !isAccountInvalid) {
        name = accountName;
      }

      final sanitized = Calendar(
        id: id,
        name: name,
        accountName: isAccountInvalid ? null : accountName,
        accountType: calendar.accountType,
        isReadOnly: calendar.isReadOnly,
        isDefault: calendar.isDefault,
        color: calendar.color,
      );

      // Deduplicate by ID
      if (!uniqueCalendars.containsKey(id)) {
        uniqueCalendars[id] = sanitized;
      }
    }

    return uniqueCalendars.values.toList();
  }

  @visibleForTesting
  List<Calendar> sanitizeAndFilterCalendarsForTesting(
    List<Calendar> rawCalendars,
  ) => _sanitizeAndFilterCalendars(rawCalendars);

  @visibleForTesting
  List<Event> deduplicateEventsForTesting(List<Event> events) =>
      _deduplicateEvents(events);

  Future<Map<String, String>> getCalendarColors({
    bool forceRefresh = false,
  }) async {
    final calendars = await getAvailableCalendars(forceRefresh: forceRefresh);
    final Map<String, String> colorMap = {};
    for (final calendar in calendars) {
      if (calendar.id != null && calendar.color != null) {
        colorMap[calendar.id!] =
            '#${calendar.color!.toUnsigned(32).toRadixString(16).padLeft(8, '0')}';
      }
    }
    return colorMap;
  }

  /// Deduplicates calendar events using eventId and composite title/time fingerprint.
  List<Event> _deduplicateEvents(List<Event> events) {
    final seenIds = <String>{};
    final seenFingerprints = <String>{};
    final List<Event> deduplicated = [];

    for (final event in events) {
      final eventId = event.eventId?.trim();
      final hasValidId = eventId != null && eventId.isNotEmpty;

      if (hasValidId && seenIds.contains(eventId)) {
        continue;
      }

      final title = event.title?.trim().toLowerCase() ?? '';
      final startMs = event.start?.millisecondsSinceEpoch ?? 0;
      final endMs = event.end?.millisecondsSinceEpoch ?? 0;
      final fingerprint = '${title}_${startMs}_${endMs}_${event.allDay}';

      if (seenFingerprints.contains(fingerprint)) {
        continue;
      }

      if (hasValidId) {
        seenIds.add(eventId);
      }
      seenFingerprints.add(fingerprint);
      deduplicated.add(event);
    }

    return deduplicated;
  }

  Future<List<Event>> getEvents({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? calendarIds,
  }) async {
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365));
    final end = endDate ?? now.add(const Duration(days: 365));
    final allEvents = <Event>[];

    final token = await _getAccessToken();

    List<String> targetCalendarIds = calendarIds ?? [];
    if (targetCalendarIds.isEmpty) {
      final cals = await getAvailableCalendars();
      targetCalendarIds = cals.map((c) => c.id).whereType<String>().toList();
    }

    // 1. On Mobile, retrieve events via native device_calendar first
    if (!kIsWeb) {
      final hasPermission = await requestPermissions();
      if (hasPermission) {
        for (final calendarId in targetCalendarIds) {
          if (calendarId == 'primary' || calendarId.contains('@')) continue;
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
              'Error accessing device calendar $calendarId',
              error: e,
              stack: s,
            );
          }
        }
      }
    }

    // 2. On Web, or if Mobile found 0 device events, query Google REST API if token is present
    if (token != null && token.isNotEmpty) {
      final googleIds = targetCalendarIds
          .where(
            (id) =>
                id == 'primary' ||
                id.contains('@') ||
                id.contains('google') ||
                kIsWeb,
          )
          .toList();
      if (googleIds.isEmpty && kIsWeb) {
        googleIds.add('primary');
      }

      final List<Event> apiEvents = [];
      await Future.wait(
        googleIds.map((calendarId) async {
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

            final response = await http
                .get(uri, headers: {'Authorization': 'Bearer $token'})
                .timeout(const Duration(seconds: 5));

            if (response.statusCode == 401 || response.statusCode == 403) {
              AppLogger.warning(
                'Google Calendar API request returned ${response.statusCode} for $calendarId: ${response.body}',
                tag: 'Calendar',
              );
              await _authService?.handleTokenRevokedOrExpired();
              throw GoogleTokenExpiredException(
                'Google Calendar token rejected by server (${response.statusCode}).',
                true,
              );
            } else if (response.statusCode == 200) {
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
                  startTime = DateTime.parse(
                    startData['dateTime'] as String,
                  ).toLocal();
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
                    endTime = DateTime.parse(
                      endData['dateTime'] as String,
                    ).toLocal();
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

                apiEvents.add(
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
            }
          } on GoogleTokenExpiredException {
            rethrow;
          } catch (e) {
            AppLogger.error(
              'Error fetching events for calendar $calendarId via API',
              error: e,
            );
          }
        }),
      );
      allEvents.addAll(apiEvents);
    }

    final result = _deduplicateEvents(allEvents);
    if (result.isNotEmpty) {
      // Proactively update cache
      unawaited(_cacheEvents(result));
      return result;
    }

    // Fallback: If 0 events were found (e.g. offline, background isolate, token expired),
    // restore from cache for the requested range so widgets never go blank
    final cached = await _getCachedEvents(
      startDate: start,
      endDate: end,
      calendarIds: targetCalendarIds,
    );
    if (cached.isNotEmpty) {
      AppLogger.info(
        'Restored ${cached.length} calendar events from local cache for widget/background',
      );
      return _deduplicateEvents(cached);
    }

    return result;
  }

  Future<void> _cacheEvents(List<Event> events) async {
    try {
      if (events.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final list = events.map((e) {
        return {
          'calendarId': e.calendarId,
          'eventId': e.eventId,
          'title': e.title,
          'description': e.description,
          'start': e.start?.toIso8601String(),
          'end': e.end?.toIso8601String(),
          'allDay': e.allDay,
        };
      }).toList();
      await prefs.setString(_keyCachedEvents, jsonEncode(list));
    } catch (e) {
      AppLogger.debug('Failed to cache calendar events: $e');
    }
  }

  Future<List<Event>> _getCachedEvents({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? calendarIds,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyCachedEvents);
      if (jsonStr == null || jsonStr.isEmpty || jsonStr == '[]') return [];

      final list = jsonDecode(jsonStr) as List<dynamic>;
      final result = <Event>[];
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final calId = map['calendarId'] as String?;
        if (calendarIds != null && calendarIds.isNotEmpty && calId != null) {
          if (!calendarIds.contains(calId)) continue;
        }

        final startStr = map['start'] as String?;
        final endStr = map['end'] as String?;
        if (startStr == null) continue;

        final start = DateTime.parse(startStr);
        final end = endStr != null
            ? DateTime.parse(endStr)
            : start.add(const Duration(hours: 1));

        if (startDate != null && end.isBefore(startDate)) continue;
        if (endDate != null && start.isAfter(endDate)) continue;

        result.add(
          Event(
            calId,
            eventId: map['eventId'] as String?,
            title: map['title'] as String?,
            description: map['description'] as String?,
            start: _toTZDateTime(start),
            end: _toTZDateTime(end),
            allDay: map['allDay'] == true,
          ),
        );
      }
      return result;
    } catch (e) {
      AppLogger.debug('Failed to read cached calendar events: $e');
      return [];
    }
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
    final token = await _getAccessToken();
    final isGoogleApiCalendar =
        kIsWeb ||
        (token != null &&
            token.isNotEmpty &&
            (calendarId == 'primary' || calendarId.contains('@')));

    if (isGoogleApiCalendar) {
      try {
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
          await _authService?.handleTokenRevokedOrExpired();
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
          'Error creating/updating calendar event via API',
          error: e,
          stack: s,
        );
      }
      return null;
    }

    if (kIsWeb) return null;

    // On Mobile: use device_calendar
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
        'Error creating/updating device calendar event',
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
    final token = await _getAccessToken();
    final isGoogleApiCalendar =
        kIsWeb ||
        (token != null &&
            token.isNotEmpty &&
            (calendarId == 'primary' || calendarId.contains('@')));

    if (isGoogleApiCalendar) {
      try {
        final uri = Uri.https(
          'www.googleapis.com',
          '/calendar/v3/calendars/$calendarId/events/$eventId',
        );

        final response = await http.delete(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 401 || response.statusCode == 403) {
          await _authService?.handleTokenRevokedOrExpired();
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
          'Error deleting calendar event via API',
          error: e,
          stack: s,
        );
      }
      return false;
    }

    if (kIsWeb) return false;

    // On Mobile: use device_calendar
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
      AppLogger.error(
        'Error deleting device calendar event',
        error: e,
        stack: s,
      );
      return false;
    }
  }
}
