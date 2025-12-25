import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // NOTE: Run scripts/update_api_keys.ps1 after updating .env file
    // SECURITY: API key is replaced by build script - never commit actual keys!
    GMSServices.provideAPIKey("GOOGLE_MAPS_API_KEY_PLACEHOLDER")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
