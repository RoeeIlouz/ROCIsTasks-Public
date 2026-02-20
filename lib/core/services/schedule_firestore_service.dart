// Service for fetching schedule data from ROCIs-Schedule Firestore database
// Uses email-based lookup to find the user's data across Firebase projects

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rocis_tasks/core/models/schedule_data.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service to fetch schedule data from the ROCIs-Schedule Firestore database.
///
/// This connects to the rocis-schedule Firebase project as a secondary app
/// and uses email-based lookup to find the user's data across Firebase projects.
class ScheduleFirestoreService {
  FirebaseFirestore? _scheduleDb;
  bool _isInitialized = false;
  Map<String, CourseData>? _coursesCache;
  DateTime? _lastCacheTime;
  String? _cachedScheduleUserId;
  String? _userEmail;
  Box? _cacheBox;
  static const String _boxName = 'scheduleCacheBox';

  // Range-based cache
  List<ScheduleEventData>? _eventsCache;
  DateTime? _lastEventsCacheTime;
  String? _eventsCacheKey; // userId_start_end

  List<AssignmentData>? _assignmentsCache;
  DateTime? _lastAssignmentsCacheTime;
  String? _assignmentsCacheKey;

  static const _cacheTtl = Duration(hours: 1);

  /// Initialize the service with the secondary Firebase app.
  ///
  /// Throws an error if the 'rocis-schedule' app is not configured.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if default Firebase app is initialized first
      if (Firebase.apps.isEmpty) {
        AppLogger.warning(
          'Default Firebase not initialized yet, skipping Schedule service init',
        );
        return;
      }

      // Get the secondary Firebase app (rocis-schedule)
      final scheduleApp = Firebase.app('rocis-schedule');
      _scheduleDb = FirebaseFirestore.instanceFor(app: scheduleApp);

      // Initialize Hive box for caching
      _cacheBox = await Hive.openBox(_boxName);

      _isInitialized = true;
      AppLogger.info('ScheduleFirestoreService initialized successfully');
    } catch (e) {
      AppLogger.error(
        'Failed to initialize ScheduleFirestoreService',
        error: e,
      );
      _isInitialized = false;
    }
  }

  /// Check if the service is ready to use.
  bool get isReady => _isInitialized && _scheduleDb != null;

  /// Check if user email is set (required for cross-app access).
  bool get isAuthenticated => _userEmail != null && _userEmail!.isNotEmpty;

  /// Get the cached schedule user ID (from rocis-schedule project).
  String? get authenticatedUserId => _cachedScheduleUserId;

  /// Set the user's email for cross-app lookup.
  ///
  /// Automatically clears the cache if the email changes.
  void setUserEmail(String? email) {
    if (_userEmail != email) {
      _userEmail = email;
      clearCache();
      AppLogger.info('User email set for schedule sync', tag: 'Schedule');
    }
  }

  /// Find the user's document ID in rocis-schedule by email.
  Future<String?> _findUserIdByEmail() async {
    if (!isReady || _userEmail == null) return null;

    // Return cached ID if available
    if (_cachedScheduleUserId != null) {
      return _cachedScheduleUserId;
    }

    final trace = FirebasePerformance.instance.newTrace('schedule_find_user');
    await trace.start();
    try {
      AppLogger.info('Looking up schedule user by email', tag: 'Schedule');

      // Query users collection for matching email
      final snapshot = await _scheduleDb!
          .collection('users')
          .where('email', isEqualTo: _userEmail)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _cachedScheduleUserId = snapshot.docs.first.id;
        AppLogger.info(
          'Found schedule user ID: $_cachedScheduleUserId',
          tag: 'Schedule',
        );
        return _cachedScheduleUserId;
      } else {
        AppLogger.warning(
          'No schedule user found with email: $_userEmail',
          tag: 'Schedule',
        );
        return null;
      }
    } catch (e) {
      AppLogger.error('Error finding user by email', tag: 'Schedule', error: e);
      return null;
    } finally {
      await trace.stop();
    }
  }

  /// Fetch all courses for a user.
  ///
  /// Used for mapping course IDs to titles and colors.
  Future<Map<String, CourseData>> getCourses(String userId) async {
    if (!isReady) {
      AppLogger.warning(
        'Schedule service not initialized, returning empty courses',
      );
      return {};
    }

    // Return memory cache if fresh
    if (_coursesCache != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheTtl) {
      return _coursesCache!;
    }

    // Try Hive cache next
    if (_coursesCache == null && _cacheBox != null) {
      final cachedData = _cacheBox!.get('courses_$userId');
      final cachedTime = _cacheBox!.get('courses_time_$userId');
      if (cachedData != null && cachedTime != null) {
        final time = DateTime.parse(cachedTime);
        if (DateTime.now().difference(time) < _cacheTtl) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(
            cachedData,
          );
          _coursesCache = data.map(
            (key, value) => MapEntry(
              key,
              CourseData.fromMap(Map<String, dynamic>.from(value)),
            ),
          );
          _lastCacheTime = time;
          AppLogger.info(
            'Loaded courses from persistent cache',
            tag: 'Schedule',
          );
          return _coursesCache!;
        }
      }
    }

    if (!isReady) {
      AppLogger.warning(
        'Schedule service not initialized, returning empty courses',
      );
      return {};
    }

    // Find the user ID in rocis-schedule by email
    final scheduleUserId = await _findUserIdByEmail();
    if (scheduleUserId == null) {
      return {};
    }

    final trace = FirebasePerformance.instance.newTrace(
      'schedule_fetch_courses',
    );
    await trace.start();
    try {
      AppLogger.info(
        'Fetching courses for user $scheduleUserId',
        tag: 'Schedule',
      );
      final snapshot = await _scheduleDb!
          .collection('users')
          .doc(scheduleUserId)
          .collection('courses')
          .get();

      final courses = <String, CourseData>{};
      for (var doc in snapshot.docs) {
        final course = CourseData.fromMap(doc.data());
        courses[course.id] = course;
      }

      // Update cache
      _coursesCache = courses;
      _lastCacheTime = DateTime.now();

      // Persist to Hive
      if (_cacheBox != null) {
        final Map<String, dynamic> persistData = courses.map(
          (key, value) => MapEntry(key, value.toMap()),
        );
        _cacheBox!.put('courses_$userId', persistData);
        _cacheBox!.put(
          'courses_time_$userId',
          _lastCacheTime!.toIso8601String(),
        );
      }

      AppLogger.info('Fetched ${courses.length} courses', tag: 'Schedule');
      return courses;
    } catch (e) {
      AppLogger.error('Error fetching courses', tag: 'Schedule', error: e);
      return {};
    } finally {
      await trace.stop();
    }
  }

  /// Fetch schedule events for a user within a date range.
  Future<List<ScheduleEventData>> getScheduleEvents(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (!isReady) return [];

    final scheduleUserId = await _findUserIdByEmail();
    if (scheduleUserId == null) return [];

    final cacheKey =
        '${scheduleUserId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';

    if (_eventsCache != null &&
        _eventsCacheKey == cacheKey &&
        _lastEventsCacheTime != null &&
        DateTime.now().difference(_lastEventsCacheTime!) < _cacheTtl) {
      return _eventsCache!;
    }

    // Try Hive cache next
    if (_eventsCache == null && _cacheBox != null) {
      final cachedData = _cacheBox!.get('events_$cacheKey');
      final cachedTime = _cacheBox!.get('events_time_$cacheKey');
      if (cachedData != null && cachedTime != null) {
        final time = DateTime.parse(cachedTime);
        if (DateTime.now().difference(time) < _cacheTtl) {
          final List<dynamic> data = List<dynamic>.from(cachedData);
          _eventsCache = data
              .map(
                (e) => ScheduleEventData.fromMap(Map<String, dynamic>.from(e)),
              )
              .toList();
          _eventsCacheKey = cacheKey;
          _lastEventsCacheTime = time;
          AppLogger.info(
            'Loaded events from persistent cache',
            tag: 'Schedule',
          );
          return _eventsCache!;
        }
      }
    }

    final trace = FirebasePerformance.instance.newTrace(
      'schedule_fetch_events',
    );
    await trace.start();
    try {
      AppLogger.info(
        'Fetching events for user $scheduleUserId',
        tag: 'Schedule',
      );

      // First get courses for color mapping
      final courses = await getCourses(userId);

      // Fetch all events
      final snapshot = await _scheduleDb!
          .collection('users')
          .doc(scheduleUserId)
          .collection('events')
          .get();

      final events = <ScheduleEventData>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final courseId = data['courseId'] as String?;
          final courseColor = courseId != null
              ? courses[courseId]?.color
              : null;

          final event = ScheduleEventData.fromMap(
            data,
            courseColor: courseColor,
          );

          if (event.recurring && event.daysOfWeek.isNotEmpty) {
            events.addAll(_expandRecurringEvent(event, startDate, endDate));
          } else {
            if (event.startTime.isAfter(
                  startDate.subtract(const Duration(days: 1)),
                ) &&
                event.startTime.isBefore(
                  endDate.add(const Duration(days: 1)),
                )) {
              events.add(event);
            }
          }
        } catch (e) {
          AppLogger.error(
            'Error parsing event ${doc.id}',
            tag: 'Schedule',
            error: e,
          );
        }
      }

      events.sort((a, b) => a.startTime.compareTo(b.startTime));

      _eventsCache = events;
      _eventsCacheKey = cacheKey;
      _lastEventsCacheTime = DateTime.now();

      // Persist to Hive
      if (_cacheBox != null) {
        final List<Map<String, dynamic>> persistData = events
            .map((e) => e.toMap())
            .toList();
        _cacheBox!.put('events_$cacheKey', persistData);
        _cacheBox!.put(
          'events_time_$cacheKey',
          _lastEventsCacheTime!.toIso8601String(),
        );
      }

      return events;
    } catch (e) {
      AppLogger.error('Error fetching events', tag: 'Schedule', error: e);
      return [];
    } finally {
      await trace.stop();
    }
  }

  /// Fetch schedule events stream for a user within a date range.
  Stream<List<ScheduleEventData>> getScheduleEventsStream(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async* {
    if (!isReady) {
      yield [];
      return;
    }

    final scheduleUserId = await _findUserIdByEmail();
    if (scheduleUserId == null) {
      yield [];
      return;
    }

    AppLogger.info(
      'Subscribing to events stream for user $scheduleUserId',
      tag: 'Schedule',
    );

    yield* _scheduleDb!
        .collection('users')
        .doc(scheduleUserId)
        .collection('events')
        .snapshots()
        .asyncMap((snapshot) async {
          try {
            final courses = await getCourses(userId);
            final events = <ScheduleEventData>[];

            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                final courseId = data['courseId'] as String?;
                final courseColor = courseId != null
                    ? courses[courseId]?.color
                    : null;

                final event = ScheduleEventData.fromMap(
                  data,
                  courseColor: courseColor,
                );

                if (event.recurring && event.daysOfWeek.isNotEmpty) {
                  events.addAll(
                    _expandRecurringEvent(event, startDate, endDate),
                  );
                } else {
                  if (event.startTime.isAfter(
                        startDate.subtract(const Duration(days: 1)),
                      ) &&
                      event.startTime.isBefore(
                        endDate.add(const Duration(days: 1)),
                      )) {
                    events.add(event);
                  }
                }
              } catch (e) {
                AppLogger.error(
                  'Error parsing event in stream',
                  tag: 'Schedule',
                  error: e,
                );
              }
            }

            events.sort((a, b) => a.startTime.compareTo(b.startTime));
            return events;
          } catch (e) {
            AppLogger.error(
              'Error processing events stream',
              tag: 'Schedule',
              error: e,
            );
            return <ScheduleEventData>[];
          }
        });
  }

  /// Fetch assignments stream for a user within a date range.
  Stream<List<AssignmentData>> getAssignmentsStream(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async* {
    if (!isReady) {
      yield [];
      return;
    }

    final scheduleUserId = await _findUserIdByEmail();
    if (scheduleUserId == null) {
      yield [];
      return;
    }

    AppLogger.info(
      'Subscribing to assignments stream for user $scheduleUserId',
      tag: 'Schedule',
    );

    yield* _scheduleDb!
        .collection('users')
        .doc(scheduleUserId)
        .collection('assignments')
        .snapshots()
        .asyncMap((snapshot) async {
          try {
            final courses = await getCourses(userId);
            final assignments = <AssignmentData>[];

            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                final courseId = data['courseId'] as String?;
                final courseColor = courseId != null
                    ? courses[courseId]?.color
                    : null;

                final assignment = AssignmentData.fromMap(
                  data,
                  courseColor: courseColor,
                );

                if (!assignment.isCompleted &&
                    assignment.dueDate.isAfter(
                      startDate.subtract(const Duration(days: 1)),
                    ) &&
                    assignment.dueDate.isBefore(
                      endDate.add(const Duration(days: 1)),
                    )) {
                  assignments.add(assignment);
                }
              } catch (e) {
                AppLogger.error(
                  'Error parsing assignment in stream',
                  tag: 'Schedule',
                  error: e,
                );
              }
            }

            assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
            return assignments;
          } catch (e) {
            AppLogger.error(
              'Error processing assignments stream',
              tag: 'Schedule',
              error: e,
            );
            return <AssignmentData>[];
          }
        });
  }

  /// Clear the courses cache (call when user changes).
  void clearCache() {
    _coursesCache = null;
    _lastCacheTime = null;
    _cachedScheduleUserId = null;
    _eventsCache = null;
    _eventsCacheKey = null;
    _lastEventsCacheTime = null;
    _assignmentsCache = null;
    _assignmentsCacheKey = null;
    _lastAssignmentsCacheTime = null;
    _cacheBox?.clear();
  }

  /// Get all schedule data combined (events + assignments) for widget display.
  Future<List<Map<String, dynamic>>> getScheduleDataForWidget(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final widgetData = <Map<String, dynamic>>[];

    final events = await getScheduleEvents(userId, startDate, endDate);
    for (var event in events) {
      widgetData.add({
        'type': 'schedule_event',
        'id': event.id,
        'title': event.title,
        'description': event.notes,
        'category_color': event.courseColor != null
            ? '#${event.courseColor!.toARGB32().toRadixString(16).padLeft(8, '0')}'
            : '#4285F4',
        'date': event.startTime.toIso8601String(),
        'endDate': event.endTime.toIso8601String(),
        'isAllDay': false,
        'location': event.location,
        'eventType': event.eventTypeName,
        'courseId': event.courseId,
      });
    }

    final assignments = await getAssignments(userId, startDate, endDate);
    for (var assignment in assignments) {
      widgetData.add({
        'type': 'assignment',
        'id': assignment.id,
        'title': assignment.title,
        'description': assignment.description,
        'category_color': assignment.courseColor != null
            ? '#${assignment.courseColor!.toARGB32().toRadixString(16).padLeft(8, '0')}'
            : '#FF9800',
        'date': assignment.dueDate.toIso8601String(),
        'isAllDay': true,
        'priority': assignment.priorityName,
        'courseId': assignment.courseId,
      });
    }

    widgetData.sort((a, b) {
      final dateA = DateTime.parse(a['date'] as String);
      final dateB = DateTime.parse(b['date'] as String);
      return dateA.compareTo(dateB);
    });

    return widgetData;
  }

  /// Fetch assignments for a user within a date range (synchronous helper).
  Future<List<AssignmentData>> getAssignments(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (!isReady) return [];

    final scheduleUserId = await _findUserIdByEmail();
    if (scheduleUserId == null) return [];

    final cacheKey =
        '${scheduleUserId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';

    if (_assignmentsCache != null &&
        _assignmentsCacheKey == cacheKey &&
        _lastAssignmentsCacheTime != null &&
        DateTime.now().difference(_lastAssignmentsCacheTime!) < _cacheTtl) {
      return _assignmentsCache!;
    }

    // Try Hive cache next
    if (_assignmentsCache == null && _cacheBox != null) {
      final cachedData = _cacheBox!.get('assignments_$cacheKey');
      final cachedTime = _cacheBox!.get('assignments_time_$cacheKey');
      if (cachedData != null && cachedTime != null) {
        final time = DateTime.parse(cachedTime);
        if (DateTime.now().difference(time) < _cacheTtl) {
          final List<dynamic> data = List<dynamic>.from(cachedData);
          _assignmentsCache = data
              .map((e) => AssignmentData.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          _assignmentsCacheKey = cacheKey;
          _lastAssignmentsCacheTime = time;
          AppLogger.info(
            'Loaded assignments from persistent cache',
            tag: 'Schedule',
          );
          return _assignmentsCache!;
        }
      }
    }

    final trace = FirebasePerformance.instance.newTrace(
      'schedule_fetch_assignments',
    );
    await trace.start();
    try {
      final courses = await getCourses(userId);
      final snapshot = await _scheduleDb!
          .collection('users')
          .doc(scheduleUserId)
          .collection('assignments')
          .get();

      final assignments = <AssignmentData>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final courseId = data['courseId'] as String?;
          final courseColor = courseId != null
              ? courses[courseId]?.color
              : null;
          final assignment = AssignmentData.fromMap(
            data,
            courseColor: courseColor,
          );

          if (!assignment.isCompleted &&
              assignment.dueDate.isAfter(
                startDate.subtract(const Duration(days: 1)),
              ) &&
              assignment.dueDate.isBefore(
                endDate.add(const Duration(days: 1)),
              )) {
            assignments.add(assignment);
          }
        } catch (e) {
          AppLogger.error(
            'Error parsing assignment',
            tag: 'Schedule',
            error: e,
          );
        }
      }

      assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      _assignmentsCache = assignments;
      _assignmentsCacheKey = cacheKey;
      _lastAssignmentsCacheTime = DateTime.now();

      // Persist to Hive
      if (_cacheBox != null) {
        final List<Map<String, dynamic>> persistData = assignments
            .map((e) => e.toMap())
            .toList();
        _cacheBox!.put('assignments_$cacheKey', persistData);
        _cacheBox!.put(
          'assignments_time_$cacheKey',
          _lastAssignmentsCacheTime!.toIso8601String(),
        );
      }

      return assignments;
    } catch (e) {
      AppLogger.error('Error fetching assignments', tag: 'Schedule', error: e);
      return [];
    } finally {
      await trace.stop();
    }
  }

  /// Expand a recurring event into individual occurrences within the date range.
  List<ScheduleEventData> _expandRecurringEvent(
    ScheduleEventData event,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final occurrences = <ScheduleEventData>[];
    var current = rangeStart;

    int maxIterations = 365;
    int iterations = 0;

    while (current.isBefore(rangeEnd) && iterations < maxIterations) {
      final dartWeekday = current.weekday;
      final scheduleWeekday = dartWeekday == 7 ? 0 : dartWeekday;

      if (event.daysOfWeek.contains(scheduleWeekday)) {
        final occurrenceStart = DateTime(
          current.year,
          current.month,
          current.day,
          event.startTime.hour,
          event.startTime.minute,
        );
        final occurrenceEnd = DateTime(
          current.year,
          current.month,
          current.day,
          event.endTime.hour,
          event.endTime.minute,
        );

        if (occurrenceStart.isAfter(
              rangeStart.subtract(const Duration(days: 1)),
            ) &&
            occurrenceStart.isBefore(rangeEnd.add(const Duration(days: 1)))) {
          occurrences.add(
            event.copyWith(
              id: '${event.id}_${current.toIso8601String().split('T')[0]}',
              startTime: occurrenceStart,
              endTime: occurrenceEnd,
            ),
          );
        }
      }

      current = current.add(const Duration(days: 1));
      iterations++;
    }

    return occurrences;
  }
}
