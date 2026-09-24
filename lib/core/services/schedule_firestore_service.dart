import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/auth/google_oauth_manager.dart';
import 'package:rocis_tasks/firebase_schedule_options.dart';

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
  final DateTime? semesterStartDate;
  final DateTime? semesterEndDate;
  final String semesterId;

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
    this.semesterStartDate,
    this.semesterEndDate,
    this.semesterId = 'semester_1',
  });

  bool occursOnDay(DateTime day) {
    if (!recurring) {
      return startTime.year == day.year &&
          startTime.month == day.month &&
          startTime.day == day.day;
    }

    final targetDay = DateTime(day.year, day.month, day.day);

    // Start boundary:
    // If a semester start date is specified, recurring classes must not occur before that date.
    // Otherwise, fallback to official Israeli academic calendar start boundaries (Afeka / Israeli universities):
    // Semester 1 (Fall / תשפ"ז): October 25, 2026.
    // Semester 2: March 14, 2027.
    // Summer Semester: August 8, 2027.
    final DateTime startBoundary;
    if (semesterStartDate != null) {
      startBoundary = DateTime(
        semesterStartDate!.year,
        semesterStartDate!.month,
        semesterStartDate!.day,
      );
    } else {
      if (semesterId == 'semester_2') {
        startBoundary = DateTime(2027, 3, 14);
      } else if (semesterId == 'semester_summer') {
        startBoundary = DateTime(2027, 8, 8);
      } else {
        startBoundary = DateTime(2026, 10, 25);
      }
    }

    if (targetDay.isBefore(startBoundary)) return false;

    // Do not occur after semester end date
    if (semesterEndDate != null) {
      final end = DateTime(
        semesterEndDate!.year,
        semesterEndDate!.month,
        semesterEndDate!.day,
      );
      if (targetDay.isAfter(end)) return false;
    }

    // Day of week matching
    // Dart DateTime weekday: 1=Mon ... 7=Sun.
    // Schedule app convention: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat.
    final int scheduleWeekday = day.weekday == DateTime.sunday
        ? 0
        : day.weekday;
    return daysOfWeek.contains(scheduleWeekday);
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'courseId': courseId,
    'courseName': courseName,
    'courseCode': courseCode,
    'location': location,
    'type': typeIndex,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'recurring': recurring ? 1 : 0,
    'daysOfWeek': daysOfWeek,
    'color': color.toARGB32(),
    'notes': notes,
    'semesterStartDate': semesterStartDate?.toIso8601String(),
    'semesterEndDate': semesterEndDate?.toIso8601String(),
    'semesterId': semesterId,
  };

  /// Construct SyncedScheduleEvent from Firestore map with course & semester lookup.
  factory SyncedScheduleEvent.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? courseMap,
    Map<String, dynamic>? semesterMap,
  }) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    DateTime? parseOptionalDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      return null;
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
    } else if (rawDays is num) {
      parsedDays = [rawDays.toInt()];
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
    } else if (map['color'] != null) {
      final rawColor = map['color'];
      if (rawColor is int) {
        eventColor = Color(rawColor);
      } else if (rawColor is num) {
        eventColor = Color(rawColor.toInt());
      } else {
        final parsed = int.tryParse(rawColor.toString());
        if (parsed != null) eventColor = Color(parsed);
      }
    }

    if (courseName.isEmpty && map['courseName'] != null) {
      courseName = map['courseName'].toString();
    }
    if (courseCode.isEmpty && map['courseCode'] != null) {
      courseCode = map['courseCode'].toString();
    }

    final isRecurring =
        map['recurring'] == 1 ||
        map['recurring'] == true ||
        map['recurring'] == '1' ||
        map['recurring'] == 'true';

    DateTime? semStart =
        parseOptionalDate(semesterMap?['startDate']) ??
        parseOptionalDate(map['semesterStartDate']);
    DateTime? semEnd =
        parseOptionalDate(semesterMap?['endDate']) ??
        parseOptionalDate(map['semesterEndDate']);

    // Fallback for standard academic semesters if dates not yet explicitly configured
    final semesterId =
        courseMap?['semester']?.toString() ??
        map['semesterId']?.toString() ??
        'semester_1';
    if (semStart == null) {
      if (semesterId == 'semester_2') {
        semStart = DateTime(2027, 3, 14);
        semEnd ??= DateTime(2027, 6, 30);
      } else if (semesterId == 'semester_summer') {
        semStart = DateTime(2027, 8, 8);
        semEnd ??= DateTime(2027, 9, 30);
      } else {
        // Semester 1 (Fall / תשפ"ז) standard academic start at Afeka / Israeli universities: late October
        semStart = DateTime(2026, 10, 25);
        semEnd ??= DateTime(2027, 2, 5);
      }
    }

    // Default semester end date if not explicitly set
    semEnd ??= semStart.add(const Duration(days: 160));

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
      recurring: isRecurring,
      daysOfWeek: parsedDays,
      color: eventColor,
      notes: map['notes']?.toString() ?? '',
      semesterStartDate: semStart,
      semesterEndDate: semEnd,
      semesterId: semesterId,
    );
  }
}

class ScheduleFirestoreService {
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
          options: ScheduleFirebaseOptions.currentPlatform,
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

  Future<String?> _getStoredEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(GoogleOAuthManager.keyUserEmail) ??
          prefs.getString('user_email');
    } catch (_) {
      return null;
    }
  }

  /// Convert Firestore REST API document fields into dynamic map
  static Map<String, dynamic> decodeFirestoreFields(
    Map<String, dynamic> fields,
  ) {
    final result = <String, dynamic>{};
    fields.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        if (val.containsKey('stringValue')) {
          result[key] = val['stringValue'];
        } else if (val.containsKey('integerValue')) {
          result[key] = int.tryParse(val['integerValue'].toString()) ?? 0;
        } else if (val.containsKey('doubleValue')) {
          result[key] = (val['doubleValue'] as num).toDouble();
        } else if (val.containsKey('booleanValue')) {
          result[key] = val['booleanValue'] == true;
        } else if (val.containsKey('timestampValue')) {
          result[key] = val['timestampValue'];
        } else if (val.containsKey('nullValue')) {
          result[key] = null;
        } else if (val.containsKey('arrayValue')) {
          final arr = val['arrayValue'] as Map<String, dynamic>;
          final values = arr['values'] as List<dynamic>? ?? [];
          result[key] = values.map((v) {
            if (v is Map<String, dynamic>) {
              return v['stringValue'] ??
                  v['integerValue'] ??
                  v['doubleValue'] ??
                  v['booleanValue'];
            }
            return v;
          }).toList();
        } else if (val.containsKey('mapValue')) {
          final mapVal = val['mapValue'] as Map<String, dynamic>;
          result[key] = decodeFirestoreFields(
            mapVal['fields'] as Map<String, dynamic>? ?? {},
          );
        }
      } else {
        result[key] = val;
      }
    });
    return result;
  }

  /// The user signed in to the ROCIs Schedule project, if any.
  User? get _scheduleUser {
    try {
      return FirebaseAuth.instanceFor(
        app: Firebase.app('rocis-schedule'),
      ).currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Auth header for REST calls. Required once the Schedule project's rules
  /// allow reads only by the data's owner; harmless while they are open.
  Future<Map<String, String>> _restAuthHeaders() async {
    try {
      final token = await _scheduleUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        return {'Authorization': 'Bearer $token'};
      }
    } catch (e) {
      debugPrint('ScheduleFirestoreService: could not get ID token: $e');
    }
    return const {};
  }

  /// Resolve ROCIs-Schedule UID via direct Firestore REST query (safe on Web & Isolates)
  Future<String?> _resolveUserIdViaRest(String targetEmail) async {
    try {
      final apiKey = ScheduleFirebaseOptions.currentPlatform.apiKey;
      final projectId = ScheduleFirebaseOptions.currentPlatform.projectId;
      final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery?key=$apiKey',
      );

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
        final body = jsonEncode({
          'structuredQuery': {
            'from': [
              {'collectionId': 'users'},
            ],
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': 'email'},
                'op': 'EQUAL',
                'value': {'stringValue': variant},
              },
            },
            'limit': 1,
          },
        });

        final resp = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                ...await _restAuthHeaders(),
              },
              body: body,
            )
            .timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body);
          if (decoded is List && decoded.isNotEmpty) {
            final first = decoded.first as Map<String, dynamic>;
            if (first.containsKey('document')) {
              final doc = first['document'] as Map<String, dynamic>;
              final docName = doc['name'] as String? ?? '';
              final resolvedUid = docName.split('/').last;
              if (resolvedUid.isNotEmpty) {
                debugPrint(
                  'ScheduleFirestoreService: Resolved user via REST ($variant) -> $resolvedUid',
                );
                return resolvedUid;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ScheduleFirestoreService: Error resolving user via REST: $e');
    }
    return null;
  }

  /// Direct REST fetch of courses, events, and semesters with metadata
  Future<List<SyncedScheduleEvent>> _fetchViaRest(String targetUserId) async {
    try {
      final apiKey = ScheduleFirebaseOptions.currentPlatform.apiKey;
      final projectId = ScheduleFirebaseOptions.currentPlatform.projectId;

      final coursesUrl = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$targetUserId/courses?key=$apiKey',
      );
      final eventsUrl = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$targetUserId/events?key=$apiKey',
      );
      final semestersUrl = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$targetUserId/semesters?key=$apiKey',
      );

      final headers = await _restAuthHeaders();
      final responses = await Future.wait([
        http
            .get(coursesUrl, headers: headers)
            .timeout(const Duration(seconds: 10)),
        http
            .get(eventsUrl, headers: headers)
            .timeout(const Duration(seconds: 10)),
        http
            .get(semestersUrl, headers: headers)
            .timeout(const Duration(seconds: 10)),
      ]);

      final coursesResp = responses[0];
      final eventsResp = responses[1];
      final semestersResp = responses[2];

      // Parse courses
      final coursesMap = <String, Map<String, dynamic>>{};
      if (coursesResp.statusCode == 200) {
        final coursesJson =
            jsonDecode(coursesResp.body) as Map<String, dynamic>;
        final courseDocs = coursesJson['documents'] as List<dynamic>? ?? [];
        for (final doc in courseDocs) {
          if (doc is Map<String, dynamic>) {
            final docName = doc['name'] as String? ?? '';
            final courseId = docName.split('/').last;
            final fields = doc['fields'] as Map<String, dynamic>? ?? {};
            coursesMap[courseId] = decodeFirestoreFields(fields);
          }
        }
      }

      // Parse semesters
      final semesterMap = <String, Map<String, dynamic>>{};
      if (semestersResp.statusCode == 200) {
        final semJson = jsonDecode(semestersResp.body) as Map<String, dynamic>;
        final semDocs = semJson['documents'] as List<dynamic>? ?? [];
        for (final doc in semDocs) {
          if (doc is Map<String, dynamic>) {
            final docName = doc['name'] as String? ?? '';
            final semId = docName.split('/').last;
            final fields = doc['fields'] as Map<String, dynamic>? ?? {};
            semesterMap[semId] = decodeFirestoreFields(fields);
          }
        }
      }

      // Parse events with course + semester metadata
      if (eventsResp.statusCode == 200) {
        final eventsJson = jsonDecode(eventsResp.body) as Map<String, dynamic>;
        final eventDocs = eventsJson['documents'] as List<dynamic>? ?? [];
        final events = <SyncedScheduleEvent>[];
        for (final doc in eventDocs) {
          if (doc is Map<String, dynamic>) {
            final fields = doc['fields'] as Map<String, dynamic>? ?? {};
            final decoded = decodeFirestoreFields(fields);
            final courseId = decoded['courseId']?.toString() ?? '';
            final course = coursesMap[courseId];
            final semId =
                course?['semester']?.toString() ??
                decoded['semesterId']?.toString() ??
                '';
            events.add(
              SyncedScheduleEvent.fromMap(
                decoded,
                courseMap: course,
                semesterMap: semesterMap[semId],
              ),
            );
          }
        }
        debugPrint(
          'ScheduleFirestoreService: Fetched ${events.length} events via REST for $targetUserId',
        );
        return events;
      }
    } catch (e) {
      debugPrint('ScheduleFirestoreService: REST fetch error: $e');
    }
    return [];
  }

  /// Fetch events from Firestore SDK instance
  Future<List<SyncedScheduleEvent>> _fetchFromFirestoreDb(
    String targetUserId,
  ) async {
    if (!isReady) {
      await initialize();
    }
    final db = _scheduleDb;
    if (db == null) return [];

    try {
      // Fetch courses, events, and semesters in parallel
      final results = await Future.wait([
        db
            .collection('users')
            .doc(targetUserId)
            .collection('courses')
            .get()
            .timeout(const Duration(seconds: 10)),
        db
            .collection('users')
            .doc(targetUserId)
            .collection('events')
            .get()
            .timeout(const Duration(seconds: 10)),
        db
            .collection('users')
            .doc(targetUserId)
            .collection('semesters')
            .get()
            .timeout(const Duration(seconds: 10)),
      ]);

      final coursesSnap = results[0];
      final eventsSnap = results[1];
      final semestersSnap = results[2];

      final coursesMap = <String, Map<String, dynamic>>{};
      for (final doc in coursesSnap.docs) {
        coursesMap[doc.id] = doc.data();
      }

      final semesterMap = <String, Map<String, dynamic>>{};
      for (final doc in semestersSnap.docs) {
        semesterMap[doc.id] = doc.data();
      }

      return eventsSnap.docs.map((doc) {
        final data = doc.data();
        final courseId = data['courseId']?.toString() ?? '';
        final course = coursesMap[courseId];
        final semId =
            course?['semester']?.toString() ??
            data['semesterId']?.toString() ??
            '';
        return SyncedScheduleEvent.fromMap(
          data,
          courseMap: course,
          semesterMap: semesterMap[semId],
        );
      }).toList();
    } catch (e) {
      debugPrint('ScheduleFirestoreService: Firestore SDK fetch error: $e');
      return [];
    }
  }

  /// Resolve user by email from Firestore SDK instance
  Future<String?> _resolveByEmailFromDb(String targetEmail) async {
    if (!isReady) {
      await initialize();
    }
    final db = _scheduleDb;
    if (db == null) return null;

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
            .get()
            .timeout(const Duration(seconds: 10));
        if (query.docs.isNotEmpty) {
          return query.docs.first.id;
        }
      } catch (e) {
        debugPrint(
          'ScheduleFirestoreService: Error querying user by email ($variant): $e',
        );
      }
    }

    // Normalized scan fallback
    try {
      final usersSnap = await db
          .collection('users')
          .limit(50)
          .get()
          .timeout(const Duration(seconds: 10));
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
            return doc.id;
          }
        }
      }
    } catch (e) {
      debugPrint(
        'ScheduleFirestoreService: Error during user collection scan: $e',
      );
    }
    return null;
  }

  /// Resolve ROCIs Schedule user ID. Email-first resolution for reliability.
  /// The secondary Firebase Auth UID may not match the schedule user document
  /// UID, so we prioritise email-based lookups which are universally correct.
  Future<String?> _resolveScheduleUserId({String? uid, String? email}) async {
    // 0. Fast path: in-memory cache (cleared on email change or self-healing)
    if (_cachedScheduleUserId != null && _cachedScheduleUserId!.isNotEmpty) {
      return _cachedScheduleUserId;
    }

    // 1. Signed in to the Schedule project: that uid owns the data and is the
    // only account the (owner-only) rules let us read. If it turns out to
    // have no events, fetchEvents self-heals via the email lookup below.
    final signedInUid = _scheduleUser?.uid;
    if (signedInUid != null && signedInUid.isNotEmpty) {
      _cachedScheduleUserId = signedInUid;
      return signedInUid;
    }

    final targetEmail = email ?? _userEmail ?? await _getStoredEmail();

    // 2. Email lookup via REST (works only while user docs are publicly readable)
    if (targetEmail != null && targetEmail.isNotEmpty) {
      final restUid = await _resolveUserIdViaRest(targetEmail);
      if (restUid != null && restUid.isNotEmpty) {
        _cachedScheduleUserId = restUid;
        _saveCachedUserId(restUid);
        return restUid;
      }
    }

    // 2. Email-first: Firestore SDK lookup
    if (targetEmail != null && targetEmail.isNotEmpty) {
      final dbUid = await _resolveByEmailFromDb(targetEmail);
      if (dbUid != null && dbUid.isNotEmpty) {
        _cachedScheduleUserId = dbUid;
        _saveCachedUserId(dbUid);
        return dbUid;
      }
    }

    // 3. SharedPreferences cached UID (set by a previous successful resolution)
    try {
      final prefs = await SharedPreferences.getInstance();
      final persistedUid = prefs.getString('cached_schedule_user_id');
      if (persistedUid != null && persistedUid.isNotEmpty) {
        _cachedScheduleUserId = persistedUid;
        return _cachedScheduleUserId;
      }
    } catch (_) {}

    // 4. Direct UID document lookup via Firestore SDK
    if (uid != null && uid.isNotEmpty) {
      if (!isReady) await initialize();
      final db = _scheduleDb;
      if (db != null) {
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
    }

    // 5. Secondary Firebase Auth UID (last resort — may produce mismatched UID)
    try {
      final scheduleApp = Firebase.app('rocis-schedule');
      final scheduleAuth = FirebaseAuth.instanceFor(app: scheduleApp);
      final secUid = scheduleAuth.currentUser?.uid;
      if (secUid != null && secUid.isNotEmpty) {
        _cachedScheduleUserId = secUid;
        // Do NOT persist secUid — it may not match the schedule user document.
        // Let fetchEvents' self-healing validate and persist on success.
        debugPrint(
          'ScheduleFirestoreService: Resolved user by secondary auth UID (not persisted): $_cachedScheduleUserId',
        );
        return _cachedScheduleUserId;
      }
    } catch (_) {}

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

  static const String _keyCachedEventsJson = 'cached_schedule_events_json';

  Future<void> _saveCachedEvents(List<SyncedScheduleEvent> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = events.map((e) => e.toMap()).toList();
      await prefs.setString(_keyCachedEventsJson, jsonEncode(list));
    } catch (e) {
      debugPrint('ScheduleFirestoreService: Failed to save cached events: $e');
    }
  }

  Future<List<SyncedScheduleEvent>> _loadCachedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyCachedEventsJson);
      if (jsonStr != null && jsonStr.isNotEmpty && jsonStr != '[]') {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        final events = decoded
            .whereType<Map<String, dynamic>>()
            .map(SyncedScheduleEvent.fromMap)
            .toList();

        // Self-heal: If any cached event lacks proper semester boundaries or occurs prior to Oct 25 2026 (e.g. Sep 20),
        // purge the stale cache so fresh data with strict semester boundaries is loaded.
        if (events.any(
          (e) =>
              e.semesterStartDate == null ||
              e.semesterStartDate!.isBefore(DateTime(2026, 10, 25)) ||
              e.occursOnDay(DateTime(2026, 9, 20)),
        )) {
          debugPrint(
            'ScheduleFirestoreService: Purged stale cached schedule events lacking proper semester bounds.',
          );
          await prefs.remove(_keyCachedEventsJson);
          return [];
        }

        return events;
      }
    } catch (e) {
      debugPrint('ScheduleFirestoreService: Failed to load cached events: $e');
    }
    return [];
  }

  /// Fetch schedule events combined with course metadata.
  /// Supports optional email for cross-app project resolution.
  Future<List<SyncedScheduleEvent>> fetchEvents({
    String? uid,
    String? email,
    bool forceRefresh = false,
  }) async {
    // 0. If in-memory cache has any event occurring before semester start (e.g. Sep 20), purge it
    if (_cachedEvents != null &&
        _cachedEvents!.any((e) => e.occursOnDay(DateTime(2026, 9, 20)))) {
      clearCache();
    }

    // 1. In-memory TTL cache (never return empty list just because cached)
    if (!forceRefresh &&
        _cachedEvents != null &&
        _cachedEvents!.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheTtl) {
      return _cachedEvents!;
    }

    if (forceRefresh) {
      clearCache();
    }

    // 2. Load local offline cache if in-memory is empty
    if (_cachedEvents == null || _cachedEvents!.isEmpty) {
      final local = await _loadCachedEvents();
      if (local.isNotEmpty) {
        _cachedEvents = local;
      }
    }

    final targetEmail = email ?? _userEmail ?? await _getStoredEmail();

    // 3. Resolve schedule user ID
    var targetUserId = await _resolveScheduleUserId(
      uid: uid,
      email: targetEmail,
    );

    List<SyncedScheduleEvent> events = [];

    // 4. Try direct REST fetch first (fast ~300ms, immune to secondary SDK auth race conditions on mobile)
    if (targetUserId != null && targetUserId.isNotEmpty) {
      events = await _fetchViaRest(targetUserId);
      if (events.isEmpty) {
        events = await _fetchFromFirestoreDb(targetUserId);
      }
    }

    // 6. SELF-HEALING: If events are STILL empty, targetUserId might be invalid or stale!
    // Invalidate stale ID and re-resolve with user email via REST & SDK
    if (events.isEmpty && targetEmail != null && targetEmail.isNotEmpty) {
      debugPrint(
        'ScheduleFirestoreService: No events for targetUserId ($targetUserId). Self-healing by email ($targetEmail)...',
      );
      _cachedScheduleUserId = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_schedule_user_id');
      } catch (_) {}

      // Try REST email lookup
      var newUserId = await _resolveUserIdViaRest(targetEmail);
      newUserId ??= await _resolveByEmailFromDb(targetEmail);

      if (newUserId != null &&
          newUserId.isNotEmpty &&
          newUserId != targetUserId) {
        targetUserId = newUserId;
        debugPrint(
          'ScheduleFirestoreService: Self-healed to targetUserId: $targetUserId',
        );
        events = await _fetchViaRest(targetUserId);
        if (events.isEmpty) {
          events = await _fetchFromFirestoreDb(targetUserId);
        }
      }
    }

    // 7. If events found, update cache and persist
    if (events.isNotEmpty) {
      _cachedEvents = events;
      _lastFetchTime = DateTime.now();
      _saveCachedEvents(events);
      if (targetUserId != null && targetUserId.isNotEmpty) {
        _cachedScheduleUserId = targetUserId;
        _saveCachedUserId(targetUserId);
      }
      return events;
    }

    // 8. If network returned empty, return previously cached events if available
    if (_cachedEvents != null && _cachedEvents!.isNotEmpty) {
      return _cachedEvents!;
    }

    final fallback = await _loadCachedEvents();
    if (fallback.isNotEmpty) {
      _cachedEvents = fallback;
      return fallback;
    }

    return [];
  }

  /// Stream schedule events with course and semester metadata
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
            final results = await Future.wait([
              _scheduleDb!
                  .collection('users')
                  .doc(uid)
                  .collection('courses')
                  .get(),
              _scheduleDb!
                  .collection('users')
                  .doc(uid)
                  .collection('semesters')
                  .get(),
            ]);
            final coursesSnap = results[0];
            final semestersSnap = results[1];

            final coursesMap = <String, Map<String, dynamic>>{};
            for (final doc in coursesSnap.docs) {
              coursesMap[doc.id] = doc.data();
            }

            final semesterMap = <String, Map<String, dynamic>>{};
            for (final doc in semestersSnap.docs) {
              semesterMap[doc.id] = doc.data();
            }

            return eventSnap.docs.map((doc) {
              final data = doc.data();
              final courseId = data['courseId']?.toString() ?? '';
              final course = coursesMap[courseId];
              final semId =
                  course?['semester']?.toString() ??
                  data['semesterId']?.toString() ??
                  '';
              return SyncedScheduleEvent.fromMap(
                data,
                courseMap: course,
                semesterMap: semesterMap[semId],
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
