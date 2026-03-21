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
            guard !accounts.allAccounts.isEmpty else {
                hasAuthorization = false
                emailService = nil
                return
            }
            let account = accounts.allAccounts[0]
            hasAuthorization =
                account.incomingServer.map { $0.authorization != .none } == true
                && account.outgoingServer.map { $0.authorization != .none } == true

            if hasAuthorization {
                emailService = EmailService(account: account)
            } else {
                emailService = nil
            }

            isPresented = false
        }
    }
}

#Preview("Content View") {
    @Previewable @State var accounts: Accounts = Accounts()

    ContentView().environment(accounts)
}
