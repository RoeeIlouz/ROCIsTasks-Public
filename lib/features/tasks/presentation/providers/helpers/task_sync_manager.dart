import 'dart:async';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/firestore_service.dart';
import 'package:rocis_tasks/core/services/google_tasks_service.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';

class TaskSyncManager {
  final AuthService _authService;
  final FirestoreService _firestoreService;
  final GoogleTasksService _googleTasksService;
  final CalendarService _calendarService;
  final LocalTaskSource _source;
  final ErrorHandlingService _errorHandlingService;

  final Map<String, bool> _pendingLocalWrites = {};
  Map<String, bool> get pendingLocalWrites => _pendingLocalWrites;

  StreamSubscription? _tasksSubscription;
  StreamSubscription? _categoriesSubscription;
  String? _completedPrefetchUserId;
  bool _completedPrefetchInFlight = false;

  TaskSyncManager({
    required AuthService authService,
    required FirestoreService firestoreService,
    required GoogleTasksService googleTasksService,
    required CalendarService calendarService,
    required LocalTaskSource source,
    required ErrorHandlingService errorHandlingService,
  })  : _authService = authService,
        _firestoreService = firestoreService,
        _googleTasksService = googleTasksService,
        _calendarService = calendarService,
        _source = source,
        _errorHandlingService = errorHandlingService;

  void recordPendingWrite(String taskId, bool isCompleted) {
    _pendingLocalWrites[taskId] = isCompleted;
  }

  void schedulePendingWriteCleanup(String taskId, {Duration delay = const Duration(seconds: 15)}) {
    Future.delayed(delay, () {
      _pendingLocalWrites.remove(taskId);
    });
  }

  Future<void> cancelSubscriptions() async {
    await _tasksSubscription?.cancel();
    await _categoriesSubscription?.cancel();
    _tasksSubscription = null;
    _categoriesSubscription = null;
  }

  Future<void> uploadLocalDataToCloud() async {
    if (_authService.currentUser == null) return;

    try {
      final tasks = _source.getTasks();
      final categories = _source.getCategories();
      for (final category in categories) {
        await _firestoreService.addCategory(category);
      }
      for (final task in tasks) {
        await _firestoreService.addTask(task);
      }
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Uploading local data to cloud',
      );
    }
  }

  Future<void> prefetchCompletedTasksIfNeeded({
    required bool showCompleted,
    required void Function() onDataChanged,
  }) async {
    if (!showCompleted) return;
    final user = _authService.currentUser;
    if (user == null) return;
    if (_completedPrefetchInFlight) return;

    final hasAnyCompletedLocally = _source
        .getTasks()
        .any((t) => t.isCompleted && !(t.isDeleted ?? false));
    if (_completedPrefetchUserId == user.uid && hasAnyCompletedLocally) {
      return;
    }

    _completedPrefetchInFlight = true;
    try {
      final completed = await _firestoreService.getNextCompletedTasksBatch();
      if (completed.isEmpty) {
        _completedPrefetchUserId = user.uid;
        return;
      }

      for (final task in completed) {
        await _source.addTask(task);
      }
      _completedPrefetchUserId = user.uid;
      onDataChanged();
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Prefetch completed tasks');
    } finally {
      _completedPrefetchInFlight = false;
    }
  }

  Future<void> startCloudSync({
    required Task? Function(String id) getTaskById,
    required Future<void> Function(Task task) scheduleTaskNotifications,
    required Future<void> Function(String taskId) cancelNotificationsById,
    required void Function() onDataChanged,
  }) async {
    if (_authService.currentUser == null) return;

    await cancelSubscriptions();
    try {
      _tasksSubscription = _firestoreService.getActiveTasksStream().listen(
        (events) async {
          bool needsUpdate = false;
          for (final event in events) {
            final cloudTask = event.task;
            final localTask = getTaskById(cloudTask.id);

            if (localTask != null && localTask.isCompleted && !cloudTask.isCompleted) {
              await cancelNotificationsById(cloudTask.id);
              needsUpdate = true;
              continue;
            }

            final pendingState = _pendingLocalWrites[cloudTask.id];
            if (pendingState != null) {
              if (event.type == SyncEventType.removed && pendingState == true) {
                if (localTask != null) {
                  localTask.isCompleted = true;
                  localTask.completedAt ??= DateTime.now();
                  await _source.addTask(localTask);
                } else {
                  cloudTask.isCompleted = true;
                  cloudTask.completedAt ??= DateTime.now();
                  await _source.addTask(cloudTask);
                }
                await cancelNotificationsById(cloudTask.id);
                needsUpdate = true;
                continue;
              }
              if (event.type != SyncEventType.removed && !pendingState) {
                if (localTask != null) {
                  localTask.isCompleted = false;
                  localTask.completedAt = null;
                  await _source.addTask(localTask);
                }
                needsUpdate = true;
                continue;
              }
            }

            if (event.type == SyncEventType.removed) {
              final (latestTask, isMissing) =
                  await _firestoreService.fetchTaskById(cloudTask.id);
              if (latestTask != null) {
                if (localTask != null && localTask.isCompleted && !latestTask.isCompleted) {
                  latestTask.isCompleted = true;
                  latestTask.completedAt = localTask.completedAt ?? DateTime.now();
                }
                await _source.addTask(latestTask);
                if (latestTask.isCompleted || (latestTask.isDeleted ?? false)) {
                  await cancelNotificationsById(latestTask.id);
                }
              } else if (isMissing) {
                await _source.deleteTask(cloudTask.id);
                await cancelNotificationsById(cloudTask.id);
              } else {
                continue;
              }
            } else {
              await _source.addTask(cloudTask);

              if (cloudTask.isCompleted || (cloudTask.isDeleted ?? false)) {
                await cancelNotificationsById(cloudTask.id);
              } else {
                await scheduleTaskNotifications(cloudTask);
              }
            }
            needsUpdate = true;
          }

          if (needsUpdate) {
            onDataChanged();
          }
        },
        onError: (error, stackTrace) {
          _errorHandlingService.logError(
            error,
            stackTrace,
            reason: 'Tasks stream error',
          );
        },
      );

      _categoriesSubscription = _firestoreService.getCategoriesStream().listen(
        (cloudCategories) async {
          for (final cloudCategory in cloudCategories) {
            await _source.addCategory(cloudCategory);
          }
          onDataChanged();
        },
        onError: (error, stackTrace) {
          _errorHandlingService.logError(
            error,
            stackTrace,
            reason: 'Categories stream error',
          );
        },
      );

      unawaited(syncGoogleTasksToLocal(
        cancelTaskNotifications: cancelNotificationsById,
        scheduleTaskNotifications: scheduleTaskNotifications,
        onDataChanged: onDataChanged,
      ));
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Starting cloud sync');
    }
  }

  Future<void> removeGoogleTask(Task task) async {
    final taskId = task.googleTaskId;
    if (taskId == null) return;

    try {
      await _googleTasksService.deleteTask(taskId: taskId);
    } catch (e, s) {
      if (e is GoogleTokenExpiredException && e.isServerRejection) {
        _authService.setGoogleTasksTokenExpired(true);
      }
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Failed to delete Google task',
      );
    }

    task.googleTaskId = null;
    task.googleTaskListId = null;
    await _source.addTask(task);
  }

  Future<void> syncTaskGoogleTasksState(
    Task task, {
    required Category? Function(String? id) getCategoryById,
  }) async {
    if (task.isDeleted ?? false) {
      await removeGoogleTask(task);
      return;
    }

    if (!task.syncWithGoogleTasks) {
      await removeGoogleTask(task);
      return;
    }

    try {
      String? categoryName;
      if (task.categoryIds.isNotEmpty) {
        categoryName = getCategoryById(task.categoryIds.first)?.name;
      } else if (task.categoryId != null) {
        categoryName = getCategoryById(task.categoryId)?.name;
      }

      if (task.googleTaskId == null) {
        final taskId = await _googleTasksService.createTask(
          title: task.title,
          description: task.description.isEmpty ? null : task.description,
          dueDate: task.dueDate,
          categoryName: categoryName,
        );

        if (taskId != null) {
          task.googleTaskId = taskId;
          task.googleTaskListId = 'ROCIs Tasks';
          await _source.addTask(task);
        }
      } else {
        final success = await _googleTasksService.updateTask(
          taskId: task.googleTaskId!,
          title: task.title,
          description: task.description.isEmpty ? null : task.description,
          dueDate: task.dueDate,
          isCompleted: task.isCompleted,
          categoryName: categoryName,
        );

        if (!success) {
          task.googleTaskId = null;
          task.googleTaskListId = null;
          await _source.addTask(task);
          await syncTaskGoogleTasksState(task, getCategoryById: getCategoryById);
        }
      }
    } catch (e, s) {
      if (e is GoogleTokenExpiredException && e.isServerRejection) {
        _authService.setGoogleTasksTokenExpired(true);
      }
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Sync task to Google Tasks failed',
      );
    }
  }

  Future<void> syncGoogleTasksToLocal({
    required Future<void> Function(String taskId) cancelTaskNotifications,
    required Future<void> Function(Task task) scheduleTaskNotifications,
    required void Function() onDataChanged,
  }) async {
    final accessToken = await _authService.getGoogleAccessToken();
    if (accessToken == null || _authService.isGoogleTasksTokenExpired) return;

    try {
      final googleTasks = await _googleTasksService.getTasks();
      if (googleTasks == null) return;

      final allLocalTasks = _source.getTasks();
      final googleTaskIds = googleTasks
          .map((t) => t['id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();

      bool needsUpdate = false;

      for (final gTask in googleTasks) {
        final gTaskId = gTask['id'] as String?;
        if (gTaskId == null) continue;

        final localTask = allLocalTasks.firstWhere(
          (t) => t.googleTaskId == gTaskId && !(t.isDeleted ?? false),
          orElse: () => Task(
            id: '',
            title: '',
            createdAt: DateTime.now(),
          ),
        );

        if (localTask.id.isNotEmpty) {
          if (_pendingLocalWrites.containsKey(localTask.id)) {
            continue;
          }

          final isCompletedInGoogle = gTask['status'] == 'completed';
          final dueStr = gTask['due'] as String?;
          if (dueStr != null) {
            final parsedDue = DateTime.tryParse(dueStr)?.toLocal();
            if (parsedDue != null && localTask.dueDate != parsedDue) {
              localTask.dueDate = parsedDue;
              await _source.addTask(localTask);
              await _firestoreService.updateTask(localTask);
              needsUpdate = true;
            }
          }

          if (isCompletedInGoogle && !localTask.isCompleted) {
            localTask.isCompleted = true;
            localTask.completedAt = DateTime.now();

            _pendingLocalWrites[localTask.id] = true;
            await _source.addTask(localTask);
            await _firestoreService.updateTask(localTask);
            await cancelTaskNotifications(localTask.id);

            schedulePendingWriteCleanup(localTask.id, delay: const Duration(seconds: 15));
            needsUpdate = true;
          } else if (!isCompletedInGoogle && localTask.isCompleted) {
            localTask.isCompleted = false;
            localTask.completedAt = null;

            _pendingLocalWrites[localTask.id] = false;
            await _source.addTask(localTask);
            await _firestoreService.updateTask(localTask);
            if (localTask.dueDate != null && localTask.dueDate!.isAfter(DateTime.now())) {
              await scheduleTaskNotifications(localTask);
            }

            schedulePendingWriteCleanup(localTask.id, delay: const Duration(seconds: 3));
            needsUpdate = true;
          }
        }
      }

      final activeLocalTasksWithGoogleId = allLocalTasks
          .where((t) => t.googleTaskId != null && !(t.isDeleted ?? false))
          .toList();

      for (final localTask in activeLocalTasksWithGoogleId) {
        if (!googleTaskIds.contains(localTask.googleTaskId)) {
          localTask.isDeleted = true;
          await _source.addTask(localTask);
          await _firestoreService.updateTask(localTask);
          await cancelTaskNotifications(localTask.id);
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        onDataChanged();
      }
    } catch (e, s) {
      if (e is GoogleTokenExpiredException && e.isServerRejection) {
        _authService.setGoogleTasksTokenExpired(true);
      }
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Sync Google Tasks back to local failed',
      );
    }
  }

  Future<void> processGoogleCalendarUpstreamRocisTasksHook({
    required bool isPremium,
    required Future<void> Function(Task task) scheduleTaskNotifications,
    required void Function() onDataChanged,
  }) async {
    if (!isPremium) return;

    try {
      final calendars = await _calendarService.getAvailableCalendars();
      final googleWritableCalendarIds = calendars
          .where((c) => c.id != null && c.isReadOnly != true)
          .where(_looksLikeGoogleCalendar)
          .map((c) => c.id!)
          .toList();
      if (googleWritableCalendarIds.isEmpty) return;

      final now = DateTime.now();
      final events = await _calendarService.getEvents(
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.add(const Duration(days: 365)),
        calendarIds: googleWritableCalendarIds,
      );
      if (events.isEmpty) return;

      var createdAny = false;
      for (final event in events) {
        final title = event.title;
        if (title == null || title.isEmpty) continue;

        final hasMarker =
            title.contains('[ROCIsTasks]') || title.contains('[RT]');
        if (!hasMarker) continue;

        final calendarId = event.calendarId;
        final eventId = event.eventId;
        final start = event.start;
        if (calendarId == null || eventId == null || start == null) continue;

        final end = event.end ?? start.add(const Duration(hours: 1));
        final taskTitle = _stripRocisTasksMarkers(title);
        final taskDescription = _buildImportedTaskDescription(
          eventDescription: event.description,
          start: start,
          end: end,
          isAllDay: event.allDay == true,
        );

        final deleted = await _calendarService.deleteEvent(
          calendarId: calendarId,
          eventId: eventId,
        );
        if (!deleted) continue;

        final task = Task(
          title: taskTitle,
          description: taskDescription,
          dueDate: start,
          priority: TaskPriority.medium,
          syncWithGoogleTasks: false,
        );
        await _source.addTask(task);
        _firestoreService.addTask(task).catchError((e, s) {
          _errorHandlingService.logError(
            e,
            s,
            reason: 'Background cloud addTask failed (calendar import)',
          );
        });
        if (task.dueDate != null && task.dueDate!.isAfter(DateTime.now())) {
          try {
            await scheduleTaskNotifications(task);
          } catch (e, s) {
            _errorHandlingService.logError(
              e,
              s,
              reason: 'Scheduling notification for imported task',
            );
          }
        }

        createdAny = true;
      }

      if (createdAny) {
        onDataChanged();
      }
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Processing upstream Google Calendar import hook',
      );
    }
  }

  bool _looksLikeGoogleCalendar(dynamic calendar) {
    try {
      final accountType = (calendar.accountType as String?)?.toLowerCase();
      final accountName = (calendar.accountName as String?)?.toLowerCase();
      final name = (calendar.name as String?)?.toLowerCase();

      return (accountType?.contains('google') ?? false) ||
          (accountType?.contains('com.google') ?? false) ||
          (accountName?.contains('gmail') ?? false) ||
          (name?.contains('google') ?? false);
    } catch (_) {
      return false;
    }
  }

  String _stripRocisTasksMarkers(String title) {
    final stripped = title
        .replaceAll('[ROCIsTasks]', '')
        .replaceAll('[RT]', '')
        .trim();
    return stripped.isEmpty ? 'Task' : stripped;
  }

  String _buildImportedTaskDescription({
    required String? eventDescription,
    required DateTime start,
    required DateTime end,
    required bool isAllDay,
  }) {
    final base = (eventDescription ?? '').trim();
    final range = isAllDay
        ? '${DateFormat.yMMMd().format(start)} → ${DateFormat.yMMMd().format(end)}'
        : '${DateFormat.yMMMd().add_Hm().format(start)} → ${DateFormat.yMMMd().add_Hm().format(end)}';
    if (base.isEmpty) return range;
    return '$base\n\n$range';
  }
}
