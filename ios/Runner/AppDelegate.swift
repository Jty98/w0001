import Flutter
import UIKit
import UserNotifications
import MessageUI
import alarm

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var iosDocumentOpenRegistered = false
  private var documentOpenHandler: IosDocumentOpenHandler?
  private var phoneMoSmsRegistered = false
  private var phoneMoSmsHandler: PhoneMoSmsHandler?

  private func registerPluginsIfNeeded(registry: FlutterPluginRegistry) {
    // Avoid duplicate registration when the same engine is reused.
    if registry.hasPlugin("InAppWebViewFlutterPlugin") { return }
    GeneratedPluginRegistrant.register(with: registry)
  }

  private func registerIosDocumentOpenChannel() {
    guard !iosDocumentOpenRegistered else { return }

    let messenger: FlutterBinaryMessenger? = {
      if let controller = window?.rootViewController as? FlutterViewController {
        return controller.binaryMessenger
      }
      return nil
    }()
    guard let messenger else { return }

    let handler = IosDocumentOpenHandler()
    documentOpenHandler = handler
    let channel = FlutterMethodChannel(
      name: "com.w0001/ios_document_open",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      handler.handle(call, result: result)
    }
    iosDocumentOpenRegistered = true
  }

  private func registerPhoneMoSmsChannel() {
    guard !phoneMoSmsRegistered else { return }

    let messenger: FlutterBinaryMessenger? = {
      if let controller = window?.rootViewController as? FlutterViewController {
        return controller.binaryMessenger
      }
      return nil
    }()
    guard let messenger else { return }

    let handler = PhoneMoSmsHandler()
    phoneMoSmsHandler = handler
    let channel = FlutterMethodChannel(
      name: "com.w0001/phone_mo_sms",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      handler.handle(call, result: result)
    }
    phoneMoSmsRegistered = true
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
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    registerIosDocumentOpenChannel()
    registerPhoneMoSmsChannel()
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    registerPluginsIfNeeded(registry: engineBridge.pluginRegistry)
    registerIosDocumentOpenChannel()
    registerPhoneMoSmsChannel()
  }
}

/// iOS 스프레드시트를 「다른 앱에서 열기」 메뉴로 넘긴다 (Quick Look·공유 시트 아님).
final class IosDocumentOpenHandler: NSObject, UIDocumentInteractionControllerDelegate {
  private var documentController: UIDocumentInteractionController?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "openInMenu" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let path = args["path"] as? String
    else {
      result(false)
      return
    }
    guard FileManager.default.fileExists(atPath: path) else {
      result(false)
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let self else {
        result(false)
        return
      }

      let fileURL = URL(fileURLWithPath: path)
      let controller = UIDocumentInteractionController(url: fileURL)
      if let uti = args["uti"] as? String, !uti.isEmpty {
        controller.uti = uti
      }
      controller.delegate = self
      self.documentController = controller

      guard let root = Self.topViewController(), root.view.window != nil else {
        result(false)
        return
      }

      let anchor = CGRect(
        x: root.view.bounds.midX,
        y: root.view.bounds.maxY - 80,
        width: 1,
        height: 1
      )
      var presented = controller.presentOpenInMenu(from: anchor, in: root.view, animated: true)
      if !presented {
        presented = controller.presentOptionsMenu(from: anchor, in: root.view, animated: true)
      }
      result(presented)
    }
  }

  func documentInteractionControllerDidDismissOpenInMenu(
    _ controller: UIDocumentInteractionController
  ) {
    documentController = nil
  }

  func documentInteractionControllerDidDismissOptionsMenu(
    _ controller: UIDocumentInteractionController
  ) {
    documentController = nil
  }

  static func topViewController(
    base: UIViewController? = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }?
      .rootViewController
  ) -> UIViewController? {
    if let nav = base as? UINavigationController {
      return topViewController(base: nav.visibleViewController)
    }
    if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
      return topViewController(base: selected)
    }
    if let presented = base?.presentedViewController {
      return topViewController(base: presented)
    }
    return base
  }
}

/// iOS 앱 내 SMS composer (MO 인증용).
final class PhoneMoSmsHandler: NSObject, MFMessageComposeViewControllerDelegate {
  private var pendingResult: FlutterResult?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "compose" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard MFMessageComposeViewController.canSendText() else {
      result(["status": "unavailable"])
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let body = args["body"] as? String
    else {
      result(["status": "invalid"])
      return
    }
    let recipients = args["recipients"] as? [String] ?? []

    pendingResult = result
    let composeVC = MFMessageComposeViewController()
    composeVC.messageComposeDelegate = self
    composeVC.recipients = recipients
    composeVC.body = body

    DispatchQueue.main.async { [weak self] in
      guard let self else {
        result(["status": "failed"])
        return
      }
      guard let root = IosDocumentOpenHandler.topViewController() else {
        self.finish(status: "failed")
        return
      }
      root.present(composeVC, animated: true)
    }
  }

  func messageComposeViewController(
    _ controller: MFMessageComposeViewController,
    didFinishWith result: MessageComposeResult
  ) {
    controller.dismiss(animated: true)
    let status: String
    switch result {
    case .sent:
      status = "sent"
    case .cancelled:
      status = "cancelled"
    case .failed:
      status = "failed"
    @unknown default:
      status = "failed"
    }
    finish(status: status)
  }

  private func finish(status: String) {
    pendingResult?(["status": status])
    pendingResult = nil
  }
}
