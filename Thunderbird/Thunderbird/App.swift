import Account
import SwiftUI

@main
struct App: SwiftUI.App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @State private var accounts: Accounts = Accounts()
    @State private var showAlert = false
    @State private var featureFlags: FeatureFlags = FeatureFlags(distribution: .current)
    @State private var pushManager: PushNotificationManager = .shared

    // MARK: App
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(accounts).environment(featureFlags).environment(pushManager)
                    .task { await pushManager.requestAuthorizationAndRegister() }
                if showAlert {
                    FeatureNotImplementedView()
                }
            }
        }.onChange(of: AlertManager.shared.showAlert) {
            showAlert = AlertManager.shared.showAlert
        }
        #if os(macOS)
        .defaultSize(width: 768.0, height: 512.0)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}
