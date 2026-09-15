import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/analytics_service.dart';

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

    final start = parseDate(map['startTime'], DateTime(2020, 1, 1));
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
  String? _userEmail;
  String? _cachedScheduleUserId;
  List<SyncedScheduleEvent>? _cachedEvents;
  DateTime? _lastFetchTime;
  static const Duration _cacheTtl = Duration(minutes: 5);

  bool get isReady => _isInitialized && _scheduleDb != null;

  /// Set user email for cross-app lookup
  void setUserEmail(String? email) {
    if (_userEmail != email) {
      _userEmail = email;
      _cachedScheduleUserId = null;
      _cachedEvents = null;
      _lastFetchTime = null;
      SharedPreferences.getInstance()
          .then((prefs) {
            prefs.remove('cached_schedule_user_id');
          })
          .catchError((_) {});
    }
  }

  /// Compatibility: clear any in-memory cached data.
  void clearCache() {
    _cachedScheduleUserId = null;
    _cachedEvents = null;
    _lastFetchTime = null;
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.remove('cached_schedule_user_id');
        })
        .catchError((_) {});
  }

  Future<void> _saveCachedUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_schedule_user_id', userId);
    } catch (_) {}
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

  /// Resolve ROCIs Schedule user ID. Checks local cache, secondary auth, direct UID doc, then queries by email.
  Future<String?> _resolveScheduleUserId({String? uid, String? email}) async {
    if (_cachedScheduleUserId != null && _cachedScheduleUserId!.isNotEmpty) {
      return _cachedScheduleUserId;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final persistedUid = prefs.getString('cached_schedule_user_id');
      if (persistedUid != null && persistedUid.isNotEmpty) {
        _cachedScheduleUserId = persistedUid;
        return _cachedScheduleUserId;
      }
    } catch (_) {}

    final db = _scheduleDb;
    if (db == null) return null;

    // 0. Check secondary Firebase Auth currentUser first
    try {
      final scheduleApp = Firebase.app('rocis-schedule');
      final scheduleAuth = FirebaseAuth.instanceFor(app: scheduleApp);
      final secUid = scheduleAuth.currentUser?.uid;
      if (secUid != null && secUid.isNotEmpty) {
        _cachedScheduleUserId = secUid;
        _saveCachedUserId(secUid);
        debugPrint(
          'ScheduleFirestoreService: Resolved user by secondary auth UID: $_cachedScheduleUserId',
        );
        return _cachedScheduleUserId;
      }
    } catch (_) {}

    // 1. Direct UID document lookup
    if (uid != null && uid.isNotEmpty) {
      try {
        final doc = await db.collection('users').doc(uid).get();
        if (doc.exists) {
          _cachedScheduleUserId = uid;
          _saveCachedUserId(uid);
          debugPrint(
            'ScheduleFirestoreService: Resolved user by UID doc: $uid',
          );
          return _cachedScheduleUserId;
        }
      } catch (e) {
        debugPrint('ScheduleFirestoreService: Error checking doc by uid: $e');
      }
    }

    // 2. Email lookup across users collection (standard + lowercase + Gmail dotless fallback)
    final targetEmail = email ?? _userEmail;
    if (targetEmail != null && targetEmail.isNotEmpty) {
      final emailVariants = <String>{targetEmail, targetEmail.toLowerCase()};
      if (targetEmail.contains('@gmail.com') ||
          targetEmail.toLowerCase().contains('@gmail.com')) {
        final parts = targetEmail.split('@');
        final userPart = parts[0];
        final domainPart = parts[1];
        final dotless = '${userPart.replaceAll('.', '')}@$domainPart';
        emailVariants.add(dotless);
        emailVariants.add(dotless.toLowerCase());
      }

      for (final variant in emailVariants) {
        try {
          final query = await db
              .collection('users')
              .where('email', isEqualTo: variant)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            _cachedScheduleUserId = query.docs.first.id;
            _saveCachedUserId(_cachedScheduleUserId!);
            if (variant != targetEmail) {
              AnalyticsService().logEvent(
                name: 'schedule_synergy_dot_fallback',
                parameters: {'match_type': 'query_variant'},
              );
            }
            debugPrint(
              'ScheduleFirestoreService: Resolved user by email ($variant) -> $_cachedScheduleUserId',
            );
            return _cachedScheduleUserId;
          }
        } catch (e) {
          debugPrint(
            'ScheduleFirestoreService: Error querying user by email ($variant): $e',
          );
        }
      }

      // 3. Fallback: scan user docs with client-side normalized email comparison
      try {
        final usersSnap = await db.collection('users').limit(50).get();
        final normTarget = targetEmail
            .split('@')
            .first
            .replaceAll('.', '')
            .toLowerCase();
        for (final doc in usersSnap.docs) {
          final docEmail = doc.data()['email']?.toString();
          if (docEmail != null) {
            final normDoc = docEmail
                .split('@')
                .first
                .replaceAll('.', '')
                .toLowerCase();
            if (normDoc == normTarget) {
              _cachedScheduleUserId = doc.id;
              _saveCachedUserId(_cachedScheduleUserId!);
              AnalyticsService().logEvent(
                name: 'schedule_synergy_dot_fallback',
                parameters: {'match_type': 'normalized_scan'},
              );
              debugPrint(
                'ScheduleFirestoreService: Resolved user by normalized scan ($docEmail) -> $_cachedScheduleUserId',
              );
              return _cachedScheduleUserId;
            }
          }
        }
      } catch (e) {
        debugPrint(
          'ScheduleFirestoreService: Error during user collection scan: $e',
        );
      }
    }

    return null;
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

  /// Fetch schedule events combined with course metadata.
  /// Supports optional email for cross-app project resolution.
  Future<List<SyncedScheduleEvent>> fetchEvents({
    String? uid,
    String? email,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedEvents != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheTtl) {
      return _cachedEvents!;
    }

    if (!isReady) {
      await initialize();
    }
    if (!isReady) return [];

    final targetUserId = await _resolveScheduleUserId(
      uid: uid,
      email: email ?? _userEmail,
    );
    if (targetUserId == null || targetUserId.isEmpty) {
      debugPrint(
        'ScheduleFirestoreService: Could not resolve schedule user (uid: $uid, email: ${email ?? _userEmail})',
      );
      return [];
    }

    try {
      final coursesSnap = await _scheduleDb!
          .collection('users')
          .doc(targetUserId)
          .collection('courses')
          .get();
      final coursesMap = <String, Map<String, dynamic>>{};
      for (final doc in coursesSnap.docs) {
        coursesMap[doc.id] = doc.data();
      }

      final eventsSnap = await _scheduleDb!
          .collection('users')
          .doc(targetUserId)
          .collection('events')
          .get();

      final events = eventsSnap.docs.map((doc) {
        final data = doc.data();
        final courseId = data['courseId']?.toString() ?? '';
        return SyncedScheduleEvent.fromMap(
          data,
          courseMap: coursesMap[courseId],
        );
      }).toList();

      _cachedEvents = events;
      _lastFetchTime = DateTime.now();
      return events;
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
