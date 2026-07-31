import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Retenu pour toute la durée de vie de l'application : c'est lui qui
  /// observe le verrouillage de l'appareil.
  private let deviceLock = DeviceLockStreamHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Verrouillage de l'appareil → verrouillage de l'application.
    FlutterEventChannel(
      name: DeviceLockStreamHandler.channel,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setStreamHandler(deviceLock)
  }
}

/// Signale à Flutter que l'appareil a été verrouillé, pour que l'application se
/// remette elle aussi sous clé.
///
/// On suit le verrouillage effectif, pas l'extinction de l'écran : iOS scelle
/// les données protégées au moment où le code redevient exigé, ce qui respecte
/// le réglage « Exiger le mot de passe ». Deux notifications, symétriques de
/// l'implémentation Android :
///
///  • `protectedDataWillBecomeUnavailable` — l'appareil se verrouille ;
///  • `protectedDataDidBecomeAvailable` — il vient d'être déverrouillé, donc il
///    était verrouillé. Ce constat rétroactif rattrape le premier signal quand
///    l'application, suspendue, ne l'a pas reçu.
///
/// Ni l'une ni l'autre ne se déclenche sur un téléphone sans code : il n'y a
/// alors rien à verrouiller, et l'application n'a pas à se montrer plus stricte
/// que l'appareil qui l'héberge.
///
/// Ce type vit dans AppDelegate.swift plutôt que dans son propre fichier : tout
/// fichier Swift ajouté au dossier Runner doit également être déclaré dans
/// project.pbxproj pour être compilé, ce qui s'oublie facilement.
class DeviceLockStreamHandler: NSObject, FlutterStreamHandler {
  static let channel = "vtc/device_lock"

  private var events: FlutterEventSink?

  func onListen(
    withArguments arguments: Any?,
    eventSink: @escaping FlutterEventSink
  ) -> FlutterError? {
    events = eventSink
    for notification in [
      UIApplication.protectedDataWillBecomeUnavailableNotification,
      UIApplication.protectedDataDidBecomeAvailableNotification,
    ] {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(appareilVerrouille),
        name: notification,
        object: nil
      )
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(self)
    events = nil
    return nil
  }

  @objc private func appareilVerrouille() {
    events?("locked")
  }
}
