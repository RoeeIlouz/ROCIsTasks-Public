import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    _platform.setMethodCallHandler(_handleMethodCall);
  }

  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  static const _platform = MethodChannel(
    'com.example.rocis_tasks/notifications',
  );

  final _actionController = StreamController<String>.broadcast();
  Stream<String> get onAction => _actionController.stream;

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

    const fln.AndroidInitializationSettings initializationSettingsAndroid =
        fln.AndroidInitializationSettings('@mipmap/launcher_icon');

    const fln.LinuxInitializationSettings initializationSettingsLinux =
        fln.LinuxInitializationSettings(defaultActionName: 'Open notification');

    const fln.InitializationSettings initializationSettings =
        fln.InitializationSettings(
          android: initializationSettingsAndroid,
          linux: initializationSettingsLinux,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _isInitialized = true;
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'rocis_tasks_channel',
          'Rocis Tasks Reminders',
          channelDescription: 'Notifications for task reminders',
          importance: fln.Importance.max,
          priority: fln.Priority.high,
        ),
      ),
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// TASK COUNT NOTIFICATION
  Future<void> showTaskCountNotification(int count, List<String> titles) async {
    try {
      await _platform.invokeMethod('updateTaskCountIcon', {
        'count': count,
        'titles': titles,
      });
    } catch (e) {
      debugPrint('Error updating task count icon (falling back): $e');

      final String body = titles.isEmpty
          ? '$count Uncompleted Tasks'
          : titles.join('\n');

      final androidDetails = fln.AndroidNotificationDetails(
        'rocis_tasks_persistent',
        'Task Counter',
        channelDescription: 'Persistent notification for uncompleted tasks',
        importance: fln.Importance.low,
        priority: fln.Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        styleInformation: fln.BigTextStyleInformation(
          body,
          contentTitle: 'Tasks Remaining',
          summaryText: '$count Tasks',
        ),
        actions: [
          fln.AndroidNotificationAction(
            'add_task',
            'Add Task',
            icon: fln.DrawableResourceAndroidBitmap('launcher_icon'),
            showsUserInterface: true,
          ),
        ],
      );

      final details = fln.NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        888,
        'Tasks Remaining',
        body,
        details,
      );
    }
  }
}
