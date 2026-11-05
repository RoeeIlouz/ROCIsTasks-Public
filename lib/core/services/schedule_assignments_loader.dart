import 'package:rocis_tasks/core/models/schedule_assignment.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';

/// The unfinished ROCIs Schedule assignments, for the home-screen widgets.
///
/// Falls back to the last copy [ScheduleFirestoreService] cached when the
/// Schedule project cannot be reached (a widget refresh in the background has
/// no signed-in session to ask with). Never throws.
Future<List<ScheduleAssignment>> loadPendingAssignments({
  required ScheduleFirestoreService scheduleService,
  String? uid,
  String? email,
  bool forceRefresh = false,
}) async {
  try {
    final all = await scheduleService.fetchAssignments(
      uid: uid,
      email: email,
      forceRefresh: forceRefresh,
    );
    return all.where((a) => !a.isCompleted).toList();
  } catch (e) {
    AppLogger.warning('Could not fetch ROCIs Schedule assignments: $e');
    return const [];
  }
}
