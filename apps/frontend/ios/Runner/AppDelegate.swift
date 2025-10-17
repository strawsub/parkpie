import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Notification
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    // Register plugins once
    GeneratedPluginRegistrant.register(with: self)

    // Gemini / Google Maps API key
    GMSServices.provideAPIKey("AIzaSyATI9kud2QgmhjNaaQl4YBgU1pBFoJuVpM")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}