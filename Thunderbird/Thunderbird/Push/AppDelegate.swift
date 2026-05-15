#if os(iOS)
import UIKit

/// Minimal UIKit app delegate bridged into the SwiftUI lifecycle via
/// `@UIApplicationDelegateAdaptor`. Its only job is to forward the APNS
/// device-token callbacks to `PushNotificationManager`; UIKit guarantees these
/// are delivered on the main thread.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        MainActor.assumeIsolated {
            PushNotificationManager.shared.didRegister(tokenData: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        MainActor.assumeIsolated {
            PushNotificationManager.shared.didFailToRegister(error: error)
        }
    }
}
#endif
