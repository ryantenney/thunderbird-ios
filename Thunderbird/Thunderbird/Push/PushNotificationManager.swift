import Account
import Foundation
import OSLog
import UserNotifications

#if os(iOS)
import UIKit
#endif

/// Where a tapped notification should take the user.
enum PushDeepLink: Equatable {
    case inbox
    case email(id: String)
}

/// Owns the APNS lifecycle and keeps mail-index's device registry in sync with
/// the configured account.
///
/// Flow: request authorization → register for remote notifications → receive
/// an APNS token → POST it to the account's mail-index `/api/devices`. The
/// token and the base URL we registered against are persisted so we can
/// unregister on sign-out even after the account is gone, and so we don't
/// re-POST an unchanged token on every launch.
@Observable
@MainActor
final class PushNotificationManager: NSObject {
    /// Shared instance so the UIKit app delegate and the SwiftUI view tree
    /// observe the same registration state.
    static let shared = PushNotificationManager()

    private(set) var deviceTokenHex: String?
    var pendingDeepLink: PushDeepLink?

    private let logger = Logger(subsystem: "net.thunderbird", category: "Push")
    private let defaults = UserDefaults.standard

    private enum DefaultsKey {
        static let token = "push.lastTokenHex"
        static let baseURL = "push.lastBaseURL"
        static let accountID = "push.lastAccountID"
    }

    /// Ask for notification permission and, if granted, register with APNS.
    /// Safe to call on every launch — the OS dedupes and tokens are reissued
    /// to `didRegister(tokenData:)`.
    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                logger.info("Notification permission denied by user")
                return
            }
        } catch {
            logger.error("Notification authorization failed: \(error)")
            return
        }
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    // MARK: APNS callbacks (called from the app delegate)

    func didRegister(tokenData: Data) {
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()
        deviceTokenHex = hex
        logger.info("APNS token received (\(hex.prefix(8))…)")
    }

    func didFailToRegister(error: Error) {
        logger.error("APNS registration failed: \(error)")
    }

    // MARK: Registration sync

    /// Reconcile mail-index's device registry with the current account.
    /// Pass `nil` on sign-out to unregister the previously-registered device.
    func syncRegistration(for account: Account?) async {
        guard let account else {
            await unregisterPrevious()
            return
        }

        guard let baseURL = MailIndexClient.baseURL(for: account) else {
            logger.debug("Account '\(account.name)' is not a JMAP/mail-index account — skipping push registration")
            return
        }

        guard let token = deviceTokenHex else {
            // Token not yet delivered; didRegister(tokenData:) → ContentView
            // will call us again once it arrives.
            logger.debug("No APNS token yet — deferring registration")
            return
        }

        // If the mail-index host changed (account switched), clean up the old
        // registration first so we don't leave a stale device behind.
        if let previousBase = defaults.string(forKey: DefaultsKey.baseURL),
            previousBase != baseURL.absoluteString
        {
            await unregisterPrevious()
        }

        let client = MailIndexClient(baseURL: baseURL)
        do {
            try await client.registerDevice(
                token: token,
                bundleID: Bundle.main.bundleIdentifier,
                label: Self.deviceLabel
            )
            defaults.set(token, forKey: DefaultsKey.token)
            defaults.set(baseURL.absoluteString, forKey: DefaultsKey.baseURL)
            defaults.set(account.id.uuidString, forKey: DefaultsKey.accountID)
            logger.info("Registered device with mail-index at \(baseURL.absoluteString)")
        } catch {
            // Best-effort: a plain Fastmail JMAP account (not mail-index) will
            // 404 here, which is expected and non-fatal.
            logger.error("Device registration failed: \(error.localizedDescription)")
        }
    }

    private func unregisterPrevious() async {
        guard let token = defaults.string(forKey: DefaultsKey.token),
            let baseString = defaults.string(forKey: DefaultsKey.baseURL),
            let baseURL = URL(string: baseString)
        else {
            return
        }
        let client = MailIndexClient(baseURL: baseURL)
        do {
            try await client.unregisterDevice(token: token)
            logger.info("Unregistered device from mail-index at \(baseString)")
        } catch {
            logger.error("Device unregistration failed: \(error.localizedDescription)")
        }
        defaults.removeObject(forKey: DefaultsKey.token)
        defaults.removeObject(forKey: DefaultsKey.baseURL)
        defaults.removeObject(forKey: DefaultsKey.accountID)
    }

    private static var deviceLabel: String {
        #if os(iOS)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "Mac"
        #endif
    }

    // MARK: Deep linking

    fileprivate func applyDeepLink(isSummary: Bool, emailID: String?) {
        if isSummary {
            pendingDeepLink = .inbox
        } else if let emailID {
            pendingDeepLink = .email(id: emailID)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the banner even when the app is foregrounded.
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let isSummary = userInfo["summary"] as? Bool == true
        let emailID = userInfo["email_id"] as? String
        Task { @MainActor in
            self.applyDeepLink(isSummary: isSummary, emailID: emailID)
        }
        completionHandler()
    }
}
