import Account
import AuthenticationServices
import Autoconfiguration
import SwiftUI

struct AuthorizationView: View {
    let username: String
    let authenticationType: AuthenticationType

    init(_ authorization: Binding<Authorization>, error: Binding<Error?>, for username: String, authenticationType: AuthenticationType = .oAuth2) {
        self.username = username
        self.authenticationType = authenticationType
        _authorization = authorization
        switch authorization.wrappedValue {
        case .basic(_, let password):
            self.password = password
        case .oauth(_, let token):
            self.token = token
            self.apiTokenString = token.description
        case .none:
            break
        }
        _error = error
    }

    @Binding private var authorization: Authorization
    @Binding private var error: Error?
    @State private var password: String = ""
    @State private var token: Token?
    @State private var apiTokenString: String = ""

    // MARK: View
    var body: some View {
        switch authenticationType {
        case .password:
            SecureField("Password", text: $password)
                .onChange(of: password) {
                    authorization = .basic(user: username, password: password)
                }
        case .oAuth2:
            OAuthButton(username, token: $token, error: $error)
                .onChange(of: token, initial: true) {
                    if let token {
                        authorization = .oauth(user: username, token: token)
                    } else {
                        authorization = .none
                    }
                }
        case .apiToken:
            SecureField("API Token", text: $apiTokenString)
                .onChange(of: apiTokenString) {
                    if apiTokenString.isEmpty {
                        authorization = .none
                    } else {
                        authorization = .oauth(user: username, token: .bearer(apiTokenString))
                    }
                }
        case .none:
            EmptyView()
        }
    }
}

#Preview("Authorization View") {
    @Previewable @State var authorization: Authorization = .none
    @Previewable @State var error: Error?

    AuthorizationView($authorization, error: $error, for: "example@thunderbird.net")
        .padding()
}
