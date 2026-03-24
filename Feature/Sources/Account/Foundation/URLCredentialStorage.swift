import Foundation
import OSLog

private let logger = Logger(subsystem: "net.thunderbird", category: "CredentialStorage")

extension URLCredentialStorage {
    func authorization(for user: String, space: URLProtectionSpace = .account) -> Authorization? {
        let allCredentials = credentials(for: space)
        let storedKeys = allCredentials?.keys.joined(separator: ", ") ?? "none"
        logger.debug("Credential lookup: key='\(user)' stored=[\(storedKeys)]")
        guard let credential = allCredentials?[user] else {
            logger.warning("Credential not found for '\(user)'")
            return nil
        }
        let auth = credential.authorization
        logger.debug("Credential found: user=\(credential.user ?? "nil") hasPassword=\(credential.password != nil)")
        return auth
    }

    func set(authorization: Authorization, persistence: URLCredential.Persistence = .permanent, space: URLProtectionSpace = .account) {
        if !authorization.password.isEmpty {
            logger.debug("Storing credential: user='\(authorization.user)' persistence=\(String(describing: persistence))")
            set(URLCredential(authorization: authorization, persistence: persistence), for: space)
        } else if let credential: URLCredential = credentials(for: space)?[authorization.user] {
            logger.debug("Removing credential (empty password): user='\(authorization.user)'")
            remove(credential, for: space)  // Remove existing credential on empty password
        }
    }

    func deleteAuthorizations(space: URLProtectionSpace = .account) {
        for credential in (credentials(for: space) ?? [:]).values {
            remove(credential, for: space)
        }
    }
}
