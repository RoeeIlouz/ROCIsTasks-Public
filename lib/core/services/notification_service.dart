import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
export 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show NotificationResponse;

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

  static const _platform = MethodChannel(
    'com.example.rocis_tasks/notifications',
  );

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
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    AppLogger.info('NotificationService initialized with timezone: $timeZoneName', tag: 'Notifications');
    
    final now = DateTime.now();
    final tzNow = tz.TZDateTime.now(tz.local);
    AppLogger.info('Timing info - Now: $now, TZNow: $tzNow, Offset: ${tzNow.timeZoneOffset}', tag: 'Notifications');

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final canScheduleExact = await androidPlugin
          .canScheduleExactNotifications();
      AppLogger.info('Can schedule exact notifications: $canScheduleExact', tag: 'Notifications');
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
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _responseController.add(response);
      },
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
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    AppLogger.info('Scheduling notification - ID: $id, Title: $title, Date: $scheduledDate', tag: 'Notifications');

    await flutterLocalNotificationsPlugin
        .zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(scheduledDate, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'rocis_tasks_channel',
              'Rocis Tasks Reminders',
              channelDescription: 'Notifications for task reminders',
              importance: Importance.max,
              priority: Priority.high,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.reminder,
              actions: [
                const AndroidNotificationAction(
                  'snooze',
                  'Snooze 15m',
                  showsUserInterface: true,
                ),
                const AndroidNotificationAction(
                  'complete',
                  'Mark Completed',
                  showsUserInterface: true,
                ),
                const AndroidNotificationAction(
                  'reschedule',
                  'Reschedule',
                  showsUserInterface: true,
                ),
              ],
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: taskId,
        )
        .then((_) {
          AppLogger.info('Successfully scheduled notification $id', tag: 'Notifications');
        })
        .catchError((e) {
          AppLogger.error('Error scheduling notification $id', error: e, tag: 'Notifications');
        });
  }

  Future<void> testImmediateNotification() async {
    debugPrint('[NotificationService] Sending test IMMEDIATE notification...');
    const androidDetails = AndroidNotificationDetails(
      'rocis_reminders_v4',
      'Task Reminders',
      channelDescription: 'Notifications for task reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      999,
      'Test Immediate',
      'If you see this, basic notifications are working!',
      details,
    );
  }

  Future<void> testScheduledNotification() async {
    debugPrint(
      '[NotificationService] Testing SCHEDULED notification (1 min from now)...',
    );
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = now.add(const Duration(minutes: 1));

    debugPrint('  - Now: $now');
    debugPrint('  - Scheduled: $scheduledDate');

    const androidDetails = AndroidNotificationDetails(
      'rocis_reminders_v4',
      'Task Reminders',
      channelDescription: 'Notifications for task reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final canScheduleExact = await androidPlugin
            .canScheduleExactNotifications();
        debugPrint(
          '  - (Pre-check) Can schedule exact notifications: $canScheduleExact',
        );
      }

      await flutterLocalNotificationsPlugin.zonedSchedule(
        998,
        'Test Scheduled',
        'This was scheduled 1 minute ago!',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint(
        '[NotificationService] Successfully scheduled test notification for $scheduledDate',
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Error scheduling test notification: $e',
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> requestPermissions() async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      try {
        await androidPlugin.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('Error requesting exact alarm permission: $e');
      }
    }
  }

  /// TASK COUNT NOTIFICATION
  Future<void> showTaskCountNotification(
    int count,
    List<String> titles, {
    String? largeIconPath,
    bool isDarkText = false,
  }) async {
    try {
      await _platform.invokeMethod('updateTaskCountIcon', {
        'count': count,
        'titles': titles,
        'largeIconPath': largeIconPath,
        'isDarkText': isDarkText,
      });
    } catch (e) {
      debugPrint('Error updating task count icon (falling back): $e');

      final String body = titles.isEmpty
          ? '$count Uncompleted Tasks'
          : titles.join('\n');

      final androidDetails = AndroidNotificationDetails(
        'rocis_tasks_persistent',
        'Task Counter',
        channelDescription: 'Persistent notification for uncompleted tasks',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: 'Tasks Remaining',
          summaryText: '$count Tasks',
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
        888,
        'Tasks Remaining',
        body,
        details,
      );
    }
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
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
