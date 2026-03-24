import Foundation

public enum ServerProtocol: String, Codable, CaseIterable, CustomStringConvertible, Identifiable {
    case jmap = "JMAP"
    case imap = "IMAP"
    case smtp = "SMTP"

    var defaultPort: Int {
        switch self {
        case .jmap: 443
        case .imap: 143
        case .smtp: 26
        }
    }

    // MARK: CustomStringConvertible
    public var description: String { rawValue }

    // MARK: Identifiable
    public var id: String { rawValue }
}

public struct Server: Codable, Equatable, Hashable, Identifiable {
    public var serverProtocol: ServerProtocol
    public var connectionSecurity: ConnectionSecurity
    public var authenticationType: AuthenticationType
    public var username: String
    public var hostname: String
    public var port: Int

    public var authorization: Authorization {
        set {  // Swap in keychain-specific user name
            guard !username.isEmpty else { return }  // Don't store credentials without a username
            let authorization: Authorization = Authorization(user: user, password: newValue.password)
            URLCredentialStorage.shared.set(authorization: authorization, persistence: .permanent)
        }
        get {
            guard !username.isEmpty,
                  let authorization: Authorization = URLCredentialStorage.shared.authorization(for: user)
            else {
                return .none
            }
            return Authorization(user: username, password: authorization.password)  // Swap out keychain-specific user name
        }
    }

    public init(
        _ serverProtocol: ServerProtocol,
        connectionSecurity: ConnectionSecurity = .none,
        authenticationType: AuthenticationType = .none,
        username: String = "",
        hostname: String = "",
        port: Int? = nil,
        id: UUID = UUID()
    ) {
        self.serverProtocol = serverProtocol
        self.connectionSecurity = connectionSecurity
        self.authenticationType = authenticationType
        self.username = username
        self.hostname = hostname
        self.port = port ?? serverProtocol.defaultPort
        self.id = id
    }

    var user: String {  // Append unique suffix for keychain: "user@example.com IMAP:E621E1F8"
        "\(username) \(serverProtocol):\(id.uuidString.components(separatedBy: "-")[0])"
    }

    // MARK: Identifiable
    public let id: UUID
}
