import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      registerWidgetChannel(messenger: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Reports the widget App Group, "group.<bundle id>". Sideloading renames the
  /// bundle ID and the group together, so it is read at runtime.
  private func registerWidgetChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.rocisapps.tasks/widgets", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "appGroupId":
        result(Bundle.main.bundleIdentifier.map { "group.\($0)" })
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
