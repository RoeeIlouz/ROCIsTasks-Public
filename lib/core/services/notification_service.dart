import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
export 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show NotificationResponse, AndroidNotificationAction;

import 'dart:async';

// Top-level function for background handling
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // We can't easily access the Provider/State here without more complex setup (like WorkManager).
  // For now, simpler actions like 'snooze' might need the app to wake up or use a separate isolation mechanism if we want TRUE background execution without UI.
  // However, FLN actions usually bring the app to foreground or at least run this callback.
  // We'll rely on the main isolate listening if the app is running, or the app opening if it's terminated.
  // If we want purely background updates, we'd need to spawn an isolate or use the plugin's background capabilities carefully.
  // For this MVP, let's assume the user taps and it might open the app or we can handle it if we are already running.
  // If the app is terminated, 'onDidReceiveNotificationResponse' (initialized in main) is called when the app launches from the action.
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    _platform.setMethodCallHandler(_handleMethodCall);
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const _platform = MethodChannel('com.rocisapps.tasks/notifications');

  final _actionController = StreamController<String>.broadcast();
  Stream<String> get onAction => _actionController.stream;

  final _responseController =
      StreamController<NotificationResponse>.broadcast();
  Stream<NotificationResponse> get onNotificationResponse =>
      _responseController.stream;

  bool _isInitialized = false;

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onNotificationAction') {
      final action = call.arguments as String;
      _actionController.add(action);
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      AppLogger.info(
        'NotificationService initialization skipped on web',
        tag: 'Notifications',
      );
      return;
    }
    tz.initializeTimeZones();
    String timeZoneName = 'UTC';
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      timeZoneName = timezoneInfo.identifier;
    } catch (e) {
      AppLogger.warning(
        'Failed to get local timezone in NotificationService: $e',
        tag: 'Notifications',
      );
    }

    if (tz.timeZoneDatabase.locations.containsKey(timeZoneName)) {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } else if (timeZoneName == 'GMT' || timeZoneName == 'UTC') {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } else {
      try {
        tz.setLocalLocation(tz.getLocation('Etc/$timeZoneName'));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    }
    AppLogger.info(
      'NotificationService initialized with timezone: $timeZoneName',
      tag: 'Notifications',
    );

    final now = DateTime.now();
    final tzNow = tz.TZDateTime.now(tz.local);
    AppLogger.info(
      'Timing info - Now: $now, TZNow: $tzNow, Offset: ${tzNow.timeZoneOffset}',
      tag: 'Notifications',
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final canScheduleExact = await androidPlugin
          .canScheduleExactNotifications();
      AppLogger.info(
        'Can schedule exact notifications: $canScheduleExact',
        tag: 'Notifications',
      );
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          linux: initializationSettingsLinux,
        );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _responseController.add,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _isInitialized = true;
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String taskId,
    String? snoozeLabel,
    String? markCompletedLabel,
    String? openTaskLabel,
    List<AndroidNotificationAction>? androidActions,
  }) async {
    if (kIsWeb) return;
    if (scheduledDate.isBefore(DateTime.now())) return;

    AppLogger.info(
      'Scheduling notification - ID: $id, Title: $title, Date: $scheduledDate',
      tag: 'Notifications',
    );

    await flutterLocalNotificationsPlugin
        .zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'rocis_tasks_channel',
              'Rocis Tasks Reminders',
              channelDescription: 'Notifications for task reminders',
              importance: Importance.max,
              priority: Priority.high,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.reminder,
              actions:
                  androidActions ??
                  [
                    if (snoozeLabel != null)
                      AndroidNotificationAction(
                        'snooze',
                        snoozeLabel,
                        showsUserInterface: true,
                      ),
                    if (markCompletedLabel != null)
                      AndroidNotificationAction(
                        'complete',
                        markCompletedLabel,
                        showsUserInterface: true,
                      ),
                    if (openTaskLabel != null)
                      AndroidNotificationAction(
                        'open_task',
                        openTaskLabel,
                        showsUserInterface: true,
                      ),
                  ],
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: taskId,
        )
        .then((_) {
          AppLogger.info(
            'Successfully scheduled notification $id',
            tag: 'Notifications',
          );
        })
        .catchError((e) {
          AppLogger.error(
            'Error scheduling notification $id',
            error: e,
            tag: 'Notifications',
          );
        });
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      try {
        await androidPlugin.requestExactAlarmsPermission();
      } catch (e) {
        // Error requesting exact alarm permission
      }
    }
  }

  /// TASK COUNT NOTIFICATION
  Future<void> showTaskCountNotification(
    int count,
    List<String> titles, {
    String? largeIconPath,
    bool isDarkText = false,
    String? uncompletedTasksLabel,
    String? tasksRemainingLabel,
    String? tasksSummaryLabel,
  }) async {
    if (kIsWeb) return;
    try {
      await _platform.invokeMethod('updateTaskCountIcon', {
        'count': count,
        'titles': titles,
        'largeIconPath': largeIconPath,
        'isDarkText': isDarkText,
      });
    } catch (e) {
      AppLogger.warning(
        'Error updating task count icon via native channel (falling back): $e',
        tag: 'Notifications',
      );

      final String body = titles.isEmpty
          ? (uncompletedTasksLabel ?? '$count Uncompleted Tasks')
          : titles.join('\n');

      final androidDetails = AndroidNotificationDetails(
        'rocis_tasks_persistent_v6',
        'Task Counter',
        channelDescription: 'Persistent notification for uncompleted tasks',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: tasksRemainingLabel ?? 'Tasks Remaining',
          summaryText: tasksSummaryLabel ?? '$count Tasks',
        ),
        actions: [
          AndroidNotificationAction(
            'add_task',
            'Add Task',
            icon: DrawableResourceAndroidBitmap('launcher_icon'),
            showsUserInterface: true,
          ),
        ],
      );

      final details = NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        id: 888,
        title: 'Tasks Remaining',
        body: body,
        notificationDetails: details,
      );
    }
  }

  Future<void> showInfoNotification({
    required String title,
    required String body,
    int id = 777,
  }) async {
    if (kIsWeb) return;
    const androidDetails = AndroidNotificationDetails(
      'rocis_tasks_info',
      'Task Information',
      channelDescription: 'General information and feedback',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  void dispose() {
    _actionController.close();
    _responseController.close();
  }

  /// separate ID for task count so it is doesn't get cancelled by cancelAll if we were to exclude it (but we won't for now)
  /// Generates a stable integer ID for a given string ID.
  /// This is necessary because String.hashCode is not guaranteed to be stable across app restarts in Dart.
  static int getNotificationId(String id) {
    var hash = 0;
    for (var i = 0; i < id.length; i++) {
      hash = 0x1fffffff & (hash + id.codeUnitAt(i));
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}
