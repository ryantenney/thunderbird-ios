import SwiftUI
import Account

struct ContentView: View {
    @State private var isPresented: Bool = false
    @State private var hasAuthorization: Bool = false
    @State private var emailService: EmailService?
    @Environment(Accounts.self) private var accounts: Accounts

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
            // Find the first account with a configured incoming server
            let configuredAccount = accounts.allAccounts.first { account in
                account.incomingServer != nil
            }

            if let account = configuredAccount {
                hasAuthorization = true
                emailService = EmailService(account: account)
                isPresented = false
            } else {
                hasAuthorization = false
                emailService = nil
            }
        }
    }
}

#Preview("Content View") {
    @Previewable @State var accounts: Accounts = Accounts()

    ContentView().environment(accounts)
}
