import Account
import Foundation
import OSLog

/// REST client for the mail-index push-device API.
///
/// mail-index is a JMAP proxy in front of Fastmail that also serves a small
/// REST surface (`/api/devices`) on the same origin as its JMAP endpoint. When
/// the user configures a JMAP account that points at their mail-index
/// instance, the same host/port serves device registration. See
/// `docs/push-notifications.md` in the mail-index repo for the contract.
struct MailIndexClient {
    let baseURL: URL

    private static let logger = Logger(subsystem: "net.thunderbird", category: "MailIndexClient")

    /// Derive the mail-index base URL from an account's incoming server.
    ///
    /// Only JMAP accounts can be mail-index instances — a plain IMAP account
    /// has no REST surface. Returns `nil` for non-JMAP accounts so callers can
    /// silently skip registration.
    static func baseURL(for account: Account) -> URL? {
        guard let server = account.incomingServer, server.serverProtocol == .jmap else {
            return nil
        }
        // Mirror EmailService's scheme logic: plaintext only when the user
        // explicitly configured no connection security (dev setups).
        #if DEBUG
        let usesTLS = server.connectionSecurity != .none
        #else
        let usesTLS = true
        #endif
        var components = URLComponents()
        components.scheme = usesTLS ? "https" : "http"
        components.host = server.hostname
        components.port = server.port
        guard let url = components.url else {
            logger.error("Could not build mail-index base URL for host '\(server.hostname)'")
            return nil
        }
        return url
    }

    // MARK: Requests

    struct DeviceRegistration: Encodable {
        let deviceToken: String
        let platform: String
        let bundleID: String?
        let label: String?

        enum CodingKeys: String, CodingKey {
            case deviceToken = "device_token"
            case platform
            case bundleID = "bundle_id"
            case label
        }
    }

    struct DeviceResponse: Decodable {
        let id: String
        let deviceToken: String
        let platform: String
        let bundleID: String?
        let label: String?
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case deviceToken = "device_token"
            case platform
            case bundleID = "bundle_id"
            case label
            case isActive = "is_active"
        }
    }

    /// `POST /api/devices` — idempotent on the device token. Re-registering an
    /// existing token reactivates it and overwrites the label/bundle id.
    @discardableResult
    func registerDevice(
        token: String,
        bundleID: String?,
        label: String?
    ) async throws -> DeviceResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/devices"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            DeviceRegistration(
                deviceToken: token,
                platform: "apns",
                bundleID: bundleID,
                label: label
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data, expected: 201)
        return try JSONDecoder().decode(DeviceResponse.self, from: data)
    }

    /// `DELETE /api/devices/{token}` — 204 on success, 404 if unknown (treated
    /// as success: the server already has no record of this device).
    func unregisterDevice(token: String) async throws {
        let url = baseURL.appendingPathComponent("api/devices").appendingPathComponent(token)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MailIndexClientError.invalidResponse
        }
        guard http.statusCode == 204 || http.statusCode == 404 else {
            throw MailIndexClientError.unexpectedStatus(http.statusCode, body: String(data: data, encoding: .utf8))
        }
    }

    private static func validate(_ response: URLResponse, data: Data, expected: Int) throws {
        guard let http = response as? HTTPURLResponse else {
            throw MailIndexClientError.invalidResponse
        }
        guard http.statusCode == expected else {
            throw MailIndexClientError.unexpectedStatus(
                http.statusCode,
                body: String(data: data, encoding: .utf8)
            )
        }
    }
}

enum MailIndexClientError: LocalizedError {
    case invalidResponse
    case unexpectedStatus(Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "mail-index returned a non-HTTP response"
        case .unexpectedStatus(let status, let body):
            return "mail-index returned HTTP \(status)\(body.map { ": \($0)" } ?? "")"
        }
    }
}
