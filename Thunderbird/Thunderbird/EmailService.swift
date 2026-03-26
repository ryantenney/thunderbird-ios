import Account
import Foundation
import IMAP
import JMAP
import OSLog

/// Bridges `Server` configuration to JMAP or IMAP protocol clients,
/// fetching emails and exposing them as `DisplayEmail` for the UI.
@Observable
@MainActor
class EmailService {
    private(set) var emails: [DisplayEmail] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    private let account: Account
    private var mailClient: MailClient?

    private let logger = Logger(subsystem: "net.thunderbird", category: "EmailService")

    init(account: Account) {
        self.account = account
    }

    /// Fetch the inbox email list from the configured server.
    func fetchInbox() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            try await withRetry {
                try await self.doFetchInbox()
            }
        } catch {
            self.error = error
            logger.error("Failed to fetch inbox: \(error)")
        }

        isLoading = false
    }

    /// Fetch the HTML body for a specific email (lazy loading on tap).
    func fetchBody(for email: DisplayEmail) async -> String? {
        if let cached = emails.first(where: { $0.id == email.id })?.htmlBody {
            return cached
        }

        do {
            let body = try await doFetchBody(for: email)
            if let body, let index = emails.firstIndex(where: { $0.id == email.id }) {
                emails[index].htmlBody = body
            }
            return body
        } catch {
            logger.error("Failed to fetch email body: \(error)")
            return nil
        }
    }

    // MARK: - Private

    private enum MailClient {
        case jmap(JMAPClient)
        case imap(IMAPClient)
    }

    // MARK: Fetch Implementations

    private func doFetchInbox() async throws {
        guard let server = account.incomingServer else {
            logger.error("No incoming server configured for account '\(self.account.name)'")
            throw EmailServiceError.noIncomingServer
        }

        logger.info("Fetching inbox: protocol=\(server.serverProtocol.rawValue) host=\(server.hostname) port=\(server.port)")

        switch server.serverProtocol {
        case .jmap:
            try await fetchJMAPInbox(server: server)
        case .imap:
            try await fetchIMAPInbox(server: server)
        default:
            throw EmailServiceError.unsupportedProtocol(server.serverProtocol)
        }
    }

    private func doFetchBody(for email: DisplayEmail) async throws -> String? {
        guard let mailClient else {
            throw EmailServiceError.notConnected
        }

        switch mailClient {
        case .jmap(let client):
            return try await fetchJMAPBody(email: email, client: client)
        case .imap(let client):
            return try await fetchIMAPBody(email: email, client: client)
        }
    }

    // MARK: JMAP

    private func fetchJMAPInbox(server: AccountServer) async throws {
        let client = makeJMAPClient(from: server)
        self.mailClient = .jmap(client)

        try await client.session()

        let mailboxes = try await client.mailboxes()
        guard let inbox = mailboxes.first(where: { $0.role == .inbox }) else {
            throw EmailServiceError.inboxNotFound
        }

        let jmapEmails = try await client.emails(in: inbox)
        emails = jmapEmails.map { DisplayEmail(from: $0) }
            .sorted { $0.date > $1.date }
        logger.info("Fetched \(self.emails.count) JMAP emails from inbox")
    }

    private func fetchJMAPBody(email: DisplayEmail, client: JMAPClient) async throws -> String? {
        let bodyConfig = JMAP.Email.GetMethod.Configuration(
            fetchTextBodyValues: true,
            fetchHTMLBodyValues: true
        )
        let fullEmails = try await client.emails([email.id], configuration: bodyConfig)
        guard let fullEmail = fullEmails.first else { return nil }

        if let html = fullEmail.htmlContent {
            return html
        }
        if let text = fullEmail.textContent {
            return "<pre style=\"font-family: sans-serif; white-space: pre-wrap;\">\(text)</pre>"
        }
        return fullEmail.preview
    }

    private func makeJMAPClient(from server: AccountServer) -> JMAPClient {
        let accountAuth = server.authorization
        let authorization = mapJMAPAuthorization(accountAuth)
        #if DEBUG
        let usesTLS = server.connectionSecurity != .none
        #else
        let usesTLS = true
        #endif
        logger.info("JMAP server: \(server.hostname):\(server.port), tls: \(usesTLS), auth type: \(authorization.label), empty: \(authorization.isEmpty)")
        let jmapServer = JMAP.Server(
            authorization: authorization,
            host: server.hostname,
            port: server.port,
            usesTLS: usesTLS
        )
        return JMAPClient(jmapServer)
    }

    private func mapJMAPAuthorization(_ auth: AccountAuthorization) -> JMAP.Authorization {
        switch auth {
        case .basic(let user, let password):
            logger.debug("Auth: basic user=\(user) password=\(password.isEmpty ? "empty" : "present")")
            return .basic(user, password)
        case .oauth(_, let token):
            logger.debug("Auth: oauth token=\(token.description.isEmpty ? "empty" : "present (\(token.description.prefix(8))...)")")
            return .bearer(token.description)
        case .none:
            logger.warning("Auth: none — credentials missing")
            return .empty
        }
    }

    // MARK: IMAP

    private func fetchIMAPInbox(server: AccountServer) async throws {
        logger.info("IMAP connecting to \(server.hostname):\(server.port)")
        let client = try makeIMAPClient(from: server)
        self.mailClient = .imap(client)

        try await client.connect()
        logger.debug("IMAP connected, logging in...")
        try await client.login()
        logger.debug("IMAP logged in, listing mailboxes...")

        let mailboxes = try await client.list()
        logger.debug("IMAP found \(mailboxes.count) mailboxes")
        guard let inbox = mailboxes.first(where: { $0.path.name.isInbox }) else {
            logger.error("IMAP inbox mailbox not found")
            throw EmailServiceError.inboxNotFound
        }

        try await client.select(mailbox: inbox)
        logger.debug("IMAP selected inbox, fetching messages...")

        let messageSet = try await client.fetch(
            attributes: .standard  // .envelope, .flags, .uid
        )

        emails = messageSet.messages.reversed().map { DisplayEmail(from: $0) }
            .sorted { $0.date > $1.date }
        logger.info("Fetched \(self.emails.count) IMAP emails from inbox")
    }

    private func fetchIMAPBody(email: DisplayEmail, client: IMAPClient) async throws -> String? {
        guard let uidValue = UInt32(email.id) else { return nil }
        let uid = IMAP.UID(rawValue: uidValue)
        let uidSet = IMAP.UIDSet(range: IMAP.UIDRange(uid))

        let messages = try await client.fetch(
            uidSet,
            attributes: [.bodySection(peek: true, IMAP.SectionSpecifier(kind: .text), nil)]
        )

        for message in messages.values {
            for component in message.components {
                if case .bodyPart(_, let data) = component {
                    return String(data: data, encoding: .utf8)
                }
            }
        }
        return nil
    }

    private func makeIMAPClient(from server: AccountServer) throws -> IMAPClient {
        guard case .basic(_, let password) = server.authorization else {
            throw EmailServiceError.imapOAuthNotSupported
        }

        let connectionSecurity: IMAP.ConnectionSecurity =
            IMAP.ConnectionSecurity(rawValue: server.connectionSecurity.rawValue) ?? .tls

        let imapServer = IMAP.Server(
            connectionSecurity,
            hostname: server.hostname,
            username: server.username,
            password: password,
            port: server.port
        )
        return IMAPClient(imapServer)
    }

    // MARK: Retry

    private func withRetry(_ operation: @escaping () async throws -> Void) async throws {
        do {
            try await operation()
        } catch {
            if shouldRetry(error) {
                logger.info("Retrying after error: \(error)")
                mailClient = nil
                try await operation()
            } else {
                throw error
            }
        }
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            let retryable: Bool = [.networkConnectionLost, .timedOut, .notConnectedToInternet]
                .contains(urlError.code)
            logger.debug("URLError \(urlError.code.rawValue) (\(urlError.localizedDescription)) — \(retryable ? "will retry" : "not retryable")")
            return retryable
        }
        if let imapError = error as? IMAPError {
            switch imapError {
            case .notConnected, .serverDisconnected, .timedOut:
                return true
            default:
                return false
            }
        }
        return false
    }
}

// MARK: - Errors

enum EmailServiceError: LocalizedError {
    case noIncomingServer
    case inboxNotFound
    case notConnected
    case unsupportedProtocol(ServerProtocol)
    case imapOAuthNotSupported

    var errorDescription: String? {
        switch self {
        case .noIncomingServer: "No incoming server configured"
        case .inboxNotFound: "Inbox mailbox not found"
        case .notConnected: "Not connected to server"
        case .unsupportedProtocol(let proto): "Unsupported protocol: \(proto)"
        case .imapOAuthNotSupported: "IMAP with OAuth is not yet supported. Please use a password-based account."
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

        // AI Analysis
        if let ai = jmapEmail.aiAnalysis {
            self.aiSummary = ai.summary
            self.aiCategories = ai.categories
            self.aiImportance = ai.importance
            self.aiSentiment = ai.sentiment
            self.aiRequiresAction = ai.requiresAction
            self.aiActionItems = ai.actionItems?.map { AIActionItem(description: $0.description, deadline: $0.deadline) }
            self.aiKeyDates = ai.keyDates?.map { AIKeyDate(date: $0.date, description: $0.description) }
        }
    }
}

// MARK: - DisplayEmail IMAP initializer

extension DisplayEmail {
    init(from message: IMAP.Message) {
        var subject = "(No Subject)"
        var sender = "Unknown"
        var senderEmail = ""
        var recipients: [String] = []
        var date = Date()
        var isRead = false
        var uid = ""
        var hasAttachment = false

        for component in message.components {
            switch component {
            case .envelope(let envelope):
                subject = envelope.subject ?? "(No Subject)"
                if let from = envelope.from.first?.addresses.first {
                    sender = from.label ?? from.value
                    senderEmail = from.value
                }
                recipients = envelope.to.flatMap { $0.addresses }.map { $0.label ?? $0.value }
                if let envelopeDate = envelope.date {
                    date = envelopeDate.date
                }
            case .flags(let flags):
                isRead = flags.contains(.seen)
            case .uid(let u):
                uid = "\(u.rawValue)"
            case .internalDate(let d):
                date = d
            case .bodyStructure(let structure, _):
                if case .valid(let bodyStructure) = structure {
                    hasAttachment = Self.detectAttachments(in: bodyStructure)
                }
            default:
                break
            }
        }

        self.init(
            id: uid.isEmpty ? UUID().uuidString : uid,
            sender: sender,
            senderEmail: senderEmail,
            subject: subject,
            preview: "",
            date: date,
            recipients: recipients,
            isRead: isRead,
            hasAttachment: hasAttachment,
            threadId: nil,
            htmlBody: nil
        )
    }

    private static func detectAttachments(in structure: IMAP.BodyStructure) -> Bool {
        switch structure {
        case .multipart(let multipart):
            return multipart.parts.contains { detectAttachments(in: $0) }
        case .singlepart(let singlepart):
            if let ext = singlepart.extension,
               let disposition = ext.dispositionAndLanguage?.disposition,
               case .attachment = disposition.kind {
                return true
            }
            return false
        }
    }
}
