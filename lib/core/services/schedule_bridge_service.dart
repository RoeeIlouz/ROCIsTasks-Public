import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ScheduleBridgeService {
  static const String scheduleUriScheme = 'rocisschedule://';
  static const String scheduleWebUrl = 'https://schedule.rocisapps.com';

  /// Check whether ROCIs Schedule app is installed on the device.
  static Future<bool> isScheduleInstalled() async {
    try {
      final uri = Uri.parse(scheduleUriScheme);
      return await canLaunchUrl(uri);
    } catch (e) {
      debugPrint('ScheduleBridgeService: Error checking installed state: $e');
      return false;
    }
  }

  /// Launch ROCIs Schedule app, or fall back to web URL.
  static Future<bool> openScheduleApp() async {
    try {
      final nativeUri = Uri.parse(scheduleUriScheme);
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }

      final webUri = Uri.parse(scheduleWebUrl);
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint('ScheduleBridgeService: Error launching ROCIs Schedule: $e');
      return false;
    }
  }

  /// Deep link to a specific timetable event in ROCIs Schedule.
  static Future<bool> openScheduleEvent({required String eventId}) async {
    try {
      final uri = Uri.parse(
        'rocisschedule://event?id=${Uri.encodeComponent(eventId)}',
      );
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return await openScheduleApp();
    } catch (e) {
      debugPrint('ScheduleBridgeService: Error launching event deep link: $e');
      return await openScheduleApp();
    }
  }
}
