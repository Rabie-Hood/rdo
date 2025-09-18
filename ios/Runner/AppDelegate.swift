import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Canal natif pour quitter l'application proprement
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "hard_exit", binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler {
      (call: FlutterMethodCall, _: FlutterResult) in
      if call.method == "quit" {
        exit(0) // tue l’application
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}