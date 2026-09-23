import Flutter
import PushKit
import UIKit
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // VoIP push registration. Inert until a real Apple Developer VoIP
    // certificate/key exists (see the calling-feature plan's Phase 6
    // blocker) — harmless to register now, and this starts working the
    // moment those credentials exist without further app-side changes.
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // MARK: - PKPushRegistryDelegate (VoIP push for CallKit)

  func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
    guard type == .voIP else { return }
    let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
    // TODO: send deviceToken to the backend once it can send real APNs
    // VoIP pushes (needs the Apple VoIP cert/key — see plan Phase 6). Until
    // then this token has nowhere to go; the fallback FCM-based path
    // (notification_service.dart's firebaseMessagingBackgroundHandler)
    // doesn't use it at all.
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  // Real VoIP pushes bypass Firebase entirely — delivered here directly by
  // iOS, never through firebaseMessagingBackgroundHandler. Left as a stub:
  // this can't be implemented correctly yet because (a) the backend can't
  // send a real APNs VoIP push without the Apple credentials this whole
  // path is blocked on, and (b) that payload's exact shape (in particular,
  // a callKitId the backend would need to compute once, consistently, and
  // hand to both this and CallBloc — see call_kit_service.dart's own
  // deterministic-UUID comment for why that must NOT be independently
  // recomputed on each platform) isn't decided until that work happens.
  // Apple requires `completion()` to still be called promptly even when
  // there's nothing to show, or iOS penalizes the app's VoIP entitlement.
  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    completion()
  }
}
