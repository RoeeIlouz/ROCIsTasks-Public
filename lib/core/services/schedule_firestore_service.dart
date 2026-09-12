import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SyncedScheduleEvent {
  final String id;
  final String title;
  final String courseId;
  final String courseName;
  final String courseCode;
  final String location;
  final int typeIndex;
  final DateTime startTime;
  final DateTime endTime;
  final bool recurring;
  final List<int> daysOfWeek;
  final Color color;
  final String notes;

  const SyncedScheduleEvent({
    required this.id,
    required this.title,
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.location,
    required this.typeIndex,
    required this.startTime,
    required this.endTime,
    required this.recurring,
    required this.daysOfWeek,
    required this.color,
    required this.notes,
  });

  bool occursOnDay(DateTime day) {
    if (recurring) {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final eventStartDay = DateTime(
        startTime.year,
        startTime.month,
        startTime.day,
      );
      if (normalizedDay.isBefore(eventStartDay)) return false;

      // Dart DateTime weekday: 1=Mon ... 7=Sun.
      // Schedule app convention: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat.
      final int scheduleWeekday = day.weekday == DateTime.sunday
          ? 0
          : day.weekday;
      return daysOfWeek.contains(scheduleWeekday);
    } else {
      return startTime.year == day.year &&
          startTime.month == day.month &&
          startTime.day == day.day;
    }
  }

  /// Construct SyncedScheduleEvent from Firestore map with course lookup.
  factory SyncedScheduleEvent.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? courseMap,
  }) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final start = parseDate(map['startTime'], DateTime.now());
    final end = parseDate(map['endTime'], start.add(const Duration(hours: 1)));

    List<int> parsedDays = [];
    final rawDays = map['daysOfWeek'];
    if (rawDays is List) {
      parsedDays = rawDays
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    } else if (rawDays is String && rawDays.isNotEmpty) {
      parsedDays = rawDays
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toList();
    }

    Color eventColor = const Color(0xFF3F51B5);
    String courseName = '';
    String courseCode = '';

    if (courseMap != null) {
      courseName = courseMap['name']?.toString() ?? '';
      courseCode = courseMap['code']?.toString() ?? '';
      final rawColor = courseMap['color'];
      if (rawColor is int) {
        eventColor = Color(rawColor);
      } else if (rawColor is num) {
        eventColor = Color(rawColor.toInt());
      } else if (rawColor != null) {
        final parsed = int.tryParse(rawColor.toString());
        if (parsed != null) eventColor = Color(parsed);
      }
    }

    return SyncedScheduleEvent(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      courseId: map['courseId']?.toString() ?? '',
      courseName: courseName,
      courseCode: courseCode,
      location: map['location']?.toString() ?? '',
      typeIndex: (map['type'] is num) ? (map['type'] as num).toInt() : 0,
      startTime: start,
      endTime: end,
      recurring: map['recurring'] == 1 || map['recurring'] == true,
      daysOfWeek: parsedDays,
      color: eventColor,
      notes: map['notes']?.toString() ?? '',
    );
  }
}

class ScheduleFirestoreService {
  static const FirebaseOptions _webOptions = FirebaseOptions(
    apiKey: 'AIzaSyD2OHYo8F6h486p58HkL8VCFDSdu7HH67c',
    appId: '1:318456267857:web:0d72df7ff505f88c53a470',
    messagingSenderId: '318456267857',
    projectId: 'rocis-schedule',
    authDomain: 'rocis-schedule.firebaseapp.com',
    storageBucket: 'rocis-schedule.firebasestorage.app',
  );

  static const FirebaseOptions _androidOptions = FirebaseOptions(
    apiKey: 'AIzaSyDfHAfG-A3o0ZUyMtudxKkah6wsTKy9z10',
    appId: '1:318456267857:android:4e12279b28b58c3353a470',
    messagingSenderId: '318456267857',
    projectId: 'rocis-schedule',
    storageBucket: 'rocis-schedule.firebasestorage.app',
  );

  static FirebaseOptions get _platformOptions {
    if (kIsWeb) return _webOptions;
    return _androidOptions;
  }

  FirebaseFirestore? _scheduleDb;
  bool _isInitialized = false;

  bool get isReady => _isInitialized && _scheduleDb != null;

  /// Compatibility: the old service used email-based lookup.
  /// The new service uses UID-based lookup, so this is a no-op.
  void setUserEmail(String? email) {
    // No-op: this service now uses UID-based lookup via fetchEvents(uid).
  }

  /// Compatibility: clear any in-memory cached data.
  void clearCache() {
    // No persistent cache in this simplified service — nothing to clear.
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint(
          'ScheduleFirestoreService: Default Firebase not initialized',
        );
        return;
      }

      FirebaseApp scheduleApp;
      try {
        scheduleApp = Firebase.app('rocis-schedule');
      } catch (_) {
        scheduleApp = await Firebase.initializeApp(
          name: 'rocis-schedule',
          options: _platformOptions,
        );
      }

      _scheduleDb = FirebaseFirestore.instanceFor(app: scheduleApp);
      _isInitialized = true;
      debugPrint(
        'ScheduleFirestoreService: Connected to rocis-schedule secondary app',
      );
    } catch (e) {
      debugPrint(
        'ScheduleFirestoreService: Secondary app init error (non-critical): $e',
      );
    }
  }

  /// Stream of courses for user
  Stream<Map<String, Map<String, dynamic>>> streamCourses(String uid) {
    if (!isReady || uid.isEmpty) {
      return Stream.value({});
    }

    return _scheduleDb!
        .collection('users')
        .doc(uid)
        .collection('courses')
        .snapshots()
        .map((snapshot) {
          final coursesMap = <String, Map<String, dynamic>>{};
          for (final doc in snapshot.docs) {
            coursesMap[doc.id] = doc.data();
          }
          return coursesMap;
        })
        .handleError((e) {
          debugPrint('ScheduleFirestoreService: Error streaming courses: $e');
          return <String, Map<String, dynamic>>{};
        });
  }

  /// Fetch schedule events combined with course metadata
  Future<List<SyncedScheduleEvent>> fetchEvents(String uid) async {
    if (!isReady) {
      await initialize();
    }
    if (!isReady || uid.isEmpty) return [];

    try {
      final coursesSnap = await _scheduleDb!
          .collection('users')
          .doc(uid)
          .collection('courses')
          .get();
      final coursesMap = <String, Map<String, dynamic>>{};
      for (final doc in coursesSnap.docs) {
        coursesMap[doc.id] = doc.data();
      }

      final eventsSnap = await _scheduleDb!
          .collection('users')
          .doc(uid)
          .collection('events')
          .get();

      return eventsSnap.docs.map((doc) {
        final data = doc.data();
        final courseId = data['courseId']?.toString() ?? '';
        return SyncedScheduleEvent.fromMap(
          data,
          courseMap: coursesMap[courseId],
        );
      }).toList();
    } catch (e) {
      debugPrint('ScheduleFirestoreService: Error fetching events: $e');
      return [];
    }
  }

  /// Stream schedule events with course metadata
  Stream<List<SyncedScheduleEvent>> streamEvents(String uid) {
    if (!isReady || uid.isEmpty) {
      return Stream.value([]);
    }

    return _scheduleDb!
        .collection('users')
        .doc(uid)
        .collection('events')
        .snapshots()
        .asyncMap((eventSnap) async {
          try {
            final coursesSnap = await _scheduleDb!
                .collection('users')
                .doc(uid)
                .collection('courses')
                .get();
            final coursesMap = <String, Map<String, dynamic>>{};
            for (final doc in coursesSnap.docs) {
              coursesMap[doc.id] = doc.data();
            }

            return eventSnap.docs.map((doc) {
              final data = doc.data();
              final courseId = data['courseId']?.toString() ?? '';
              return SyncedScheduleEvent.fromMap(
                data,
                courseMap: coursesMap[courseId],
              );
            }).toList();
          } catch (e) {
            debugPrint(
              'ScheduleFirestoreService: Error mapping events stream: $e',
            );
            return <SyncedScheduleEvent>[];
          }
        })
        .handleError((e) {
          debugPrint('ScheduleFirestoreService: Stream error: $e');
          return <SyncedScheduleEvent>[];
        });
  }
}
