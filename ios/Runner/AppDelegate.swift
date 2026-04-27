import Flutter
import UIKit
import UserNotifications
import alarm

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private func registerPluginsIfNeeded(registry: FlutterPluginRegistry) {
    // Avoid duplicate registration when the same engine is reused.
    if registry.hasPlugin("InAppWebViewFlutterPlugin") { return }
    GeneratedPluginRegistrant.register(with: registry)
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    registerPluginsIfNeeded(registry: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    SwiftAlarmPlugin.registerBackgroundTasks()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    registerPluginsIfNeeded(registry: engineBridge.pluginRegistry)
  }
}
