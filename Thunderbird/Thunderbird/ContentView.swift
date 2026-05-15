import SwiftUI
import Account

struct ContentView: View {
    @State private var isPresented: Bool = false
    @State private var hasAuthorization: Bool = false
    @State private var emailService: EmailService?
    @Environment(Accounts.self) private var accounts: Accounts
    @Environment(PushNotificationManager.self) private var pushManager: PushNotificationManager

    private var configuredAccount: Account? {
        accounts.allAccounts.first { $0.incomingServer != nil }
    }

    // MARK: View
    var body: some View {
        VStack {
            if hasAuthorization, let emailService {
                EmailListView(emailService: emailService)
                    .environment(accounts)

            } else {
                NavigationStack {
                    WelcomeScreen($isPresented)
                }
                .sheet(isPresented: $isPresented) {
                    ManualAccount()
                }
                .presentationDragIndicator(.visible)

            }

        }
        .onChange(of: accounts.allAccounts, initial: true) {
            let account = configuredAccount
            if let account {
                hasAuthorization = true
                emailService = EmailService(account: account)
                isPresented = false
            } else {
                hasAuthorization = false
                emailService = nil
            }
            // Keep mail-index's device registry in sync. Passing nil on
            // sign-out unregisters the previously-registered device.
            Task { await pushManager.syncRegistration(for: account) }
        }
        .onChange(of: pushManager.deviceTokenHex) {
            // The APNS token usually arrives after the account is already
            // configured; register once it does.
            guard let account = configuredAccount else { return }
            Task { await pushManager.syncRegistration(for: account) }
        }
    }
}

#Preview("Content View") {
    @Previewable @State var accounts: Accounts = Accounts()

    ContentView().environment(accounts).environment(PushNotificationManager.shared)
}
