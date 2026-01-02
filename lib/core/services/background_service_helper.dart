import 'package:rocis_tasks/core/services/app_initializer.dart';

class BackgroundServiceHelper {
  static Future<void> initBackgroundServices() async {
    await AppInitializer.initialize(isBackground: true);
  }
}
