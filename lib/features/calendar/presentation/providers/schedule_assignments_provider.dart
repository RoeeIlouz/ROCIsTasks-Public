import 'package:flutter/foundation.dart';
import 'package:rocis_tasks/core/models/schedule_assignment.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';

/// Read-only view of the user's ROCIs Schedule assignments.
///
/// Assignments, and the files attached to them, are created in ROCIs Schedule;
/// this only reads them (through [ScheduleFirestoreService], which already
/// knows how to find the signed-in user's Schedule data).
class ScheduleAssignmentsProvider extends ChangeNotifier {
  final ScheduleFirestoreService _service;
  final AuthService? _authService;

  List<ScheduleAssignment> _items = const [];
  Map<String, SyncedScheduleEvent> _eventsById = const {};
  bool _isLoading = false;
  bool _hasLoaded = false;

  String? _lastUid;

  ScheduleAssignmentsProvider(this._service, {AuthService? authService})
    : _authService = authService {
    _lastUid = _authService?.currentUser?.uid;
    _authService?.addListener(_onAuthChanged);
  }

  /// Re-reads silently when a different user signs in.
  void _onAuthChanged() {
    final uid = _authService?.currentUser?.uid;
    if (uid == _lastUid) return;
    _lastUid = uid;
    if (uid != null) load(forceRefresh: true);
  }

  @override
  void dispose() {
    _authService?.removeListener(_onAuthChanged);
    super.dispose();
  }

  List<ScheduleAssignment> get items => _items;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  /// Overdue first (oldest due first), then upcoming by due date.
  List<ScheduleAssignment> overdue(DateTime now) =>
      _items.where((a) => a.isOverdue(now)).toList();

  List<ScheduleAssignment> upcoming(DateTime now) =>
      _items.where((a) => !a.isCompleted && !a.isOverdue(now)).toList();

  /// Most recently due first.
  List<ScheduleAssignment> completed() =>
      _items.where((a) => a.isCompleted).toList().reversed.toList();

  /// The lecture [assignment] was given in, if that class still exists.
  SyncedScheduleEvent? lectureFor(ScheduleAssignment assignment) {
    final id = assignment.lectureEventId;
    return id == null ? null : _eventsById[id];
  }

  Future<void> load({bool forceRefresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      final user = _authService?.currentUser;
      // The Schedule project only lets its owner read, so the secondary
      // sign-in must be in place before asking (the calendar does the same).
      if (user != null) {
        try {
          await _authService?.ensureSecondaryAuth();
        } catch (e) {
          AppLogger.warning('Schedule assignments: secondary auth failed: $e');
        }
      }
      final results = await Future.wait([
        _service.fetchAssignments(
          uid: user?.uid,
          email: user?.email,
          forceRefresh: forceRefresh,
        ),
        _service.fetchEvents(
          uid: user?.uid,
          email: user?.email,
          forceRefresh: forceRefresh,
        ),
      ]);
      _items = results[0] as List<ScheduleAssignment>;
      _eventsById = {
        for (final e in results[1] as List<SyncedScheduleEvent>) e.id: e,
      };
      _hasLoaded = true;
    } catch (e, s) {
      AppLogger.error(
        'Could not load ROCIs Schedule assignments',
        error: e,
        stack: s,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Unfinished assignments, overdue first. These stay until marked done.
  List<ScheduleAssignment> get pending =>
      _items.where((a) => !a.isCompleted).toList();

  /// Unfinished assignments due on the calendar day of [day].
  List<ScheduleAssignment> pendingDueOn(DateTime day) => pending
      .where(
        (a) =>
            a.dueDate.year == day.year &&
            a.dueDate.month == day.month &&
            a.dueDate.day == day.day,
      )
      .toList();

  /// Marks [assignment] done (or not). The list updates at once and goes back
  /// if Schedule could not be updated. Returns whether it was saved.
  Future<bool> setCompleted(ScheduleAssignment assignment, bool done) async {
    final index = _items.indexWhere((a) => a.id == assignment.id);
    if (index < 0) return false;
    final previous = _items;
    _items = [
      for (final a in _items) a.id == assignment.id ? a.withCompleted(done) : a,
    ];
    notifyListeners();

    final saved = await _service.setAssignmentCompleted(assignment.id, done);
    if (!saved) {
      _items = previous;
      notifyListeners();
    }
    return saved;
  }

  Future<Uint8List?> bytesFor(
    ScheduleAssignment assignment,
    ScheduleAttachment attachment,
  ) => _service.fetchAttachmentBytes(assignment.id, attachment);
}
