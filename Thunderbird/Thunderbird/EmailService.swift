import Account
import Foundation
import JMAP
import OSLog

/// Bridges `Account.Server` configuration to the JMAP protocol client,
/// fetching emails and exposing them as `DisplayEmail` for the UI.
@Observable
@MainActor
class EmailService {
    private(set) var emails: [DisplayEmail] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    private let account: Account.Account
    private var client: JMAPClient?
    private var inboxMailbox: JMAP.Mailbox?

    private let logger = Logger(subsystem: "net.thunderbird", category: "EmailService")

    init(account: Account.Account) {
        self.account = account
    }

    /// Fetch the inbox email list from the JMAP server.
    func fetchInbox() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let client = try makeClient()
            self.client = client

            // Start session
            try await client.session()

            // Find the inbox mailbox
            let mailboxes = try await client.mailboxes()
            guard let inbox = mailboxes.first(where: { $0.role == .inbox }) else {
                throw EmailServiceError.inboxNotFound
            }
            self.inboxMailbox = inbox

            // Fetch emails in inbox
            let jmapEmails = try await client.emails(in: inbox)

            // Map to display model
            emails = jmapEmails.map { DisplayEmail(from: $0) }
            logger.info("Fetched \(self.emails.count) emails from inbox")
        } catch {
            self.error = error
            logger.error("Failed to fetch inbox: \(error)")
        }

        isLoading = false
    }

    /// Fetch the HTML body for a specific email (lazy loading on tap).
    func fetchBody(for email: DisplayEmail) async -> String? {
        // JMAP emails include preview but not full body in the initial fetch.
        // If we already have the body cached, return it.
        if let cached = emails.first(where: { $0.id == email.id })?.htmlBody {
            return cached
        }

        do {
            guard let client else {
                throw EmailServiceError.notConnected
            }
            let fullEmails = try await client.emails([email.id])
            guard let fullEmail = fullEmails.first else {
                return nil
            }

            // Update the cached email with body content
            let body = fullEmail.preview ?? ""
            if let index = emails.firstIndex(where: { $0.id == email.id }) {
                emails[index].htmlBody = body
            }
            return body
        } catch {
            logger.error("Failed to fetch email body: \(error)")
            return nil
        }
    }

    // MARK: - Private

    private func makeClient() throws -> JMAPClient {
        guard let server = account.incomingServer else {
            throw EmailServiceError.noIncomingServer
        }
        guard server.serverProtocol == .jmap else {
            throw EmailServiceError.unsupportedProtocol(server.serverProtocol)
        }

        let authorization = mapAuthorization(server.authorization)
        let jmapServer = JMAP.Server(
            authorization: authorization,
            host: server.hostname,
            port: server.port
        )
        return JMAPClient(jmapServer)
    }

    /// Map `Account.Authorization` to `JMAP.Authorization`.
    private func mapAuthorization(_ auth: Account.Authorization) -> JMAP.Authorization {
        switch auth {
        case .basic(let user, let password):
            return .basic(user, password)
        case .oauth(_, let token):
            return .bearer(token.description)
        case .none:
            return .empty
        }
    }
}

enum EmailServiceError: LocalizedError {
    case noIncomingServer
    case inboxNotFound
    case notConnected
    case unsupportedProtocol(Account.ServerProtocol)

    var errorDescription: String? {
        switch self {
        case .noIncomingServer: "No incoming server configured"
        case .inboxNotFound: "Inbox mailbox not found"
        case .notConnected: "Not connected to server"
        case .unsupportedProtocol(let proto): "Unsupported protocol: \(proto)"
        }
    }
}

// MARK: - DisplayEmail JMAP initializer

extension DisplayEmail {
    init(from jmapEmail: JMAP.Email) {
        let senderAddress = jmapEmail.from?.first
        self.id = jmapEmail.id
        self.sender = senderAddress?.name ?? senderAddress?.email ?? "Unknown"
        self.senderEmail = senderAddress?.email ?? ""
        self.subject = jmapEmail.subject ?? "(No Subject)"
        self.preview = jmapEmail.preview ?? ""
        self.date = jmapEmail.sentAt ?? jmapEmail.receivedAt ?? Date()
        self.recipients = (jmapEmail.to ?? []).map { $0.name ?? $0.email }
        self.isRead = jmapEmail.keywords[JMAP.Email.Keyword.seen.rawValue] == true
        self.hasAttachment = jmapEmail.hasAttachment
        self.threadId = jmapEmail.threadID
        self.htmlBody = nil  // Loaded lazily
    }
}
