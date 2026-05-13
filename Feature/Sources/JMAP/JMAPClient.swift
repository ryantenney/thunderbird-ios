import Foundation
import OSLog

/// Configure `JMAPClient` with a single ``Server``.
public class JMAPClient: @unchecked Sendable {

    /// Convenience
    /// - Parameter server: ``Server`` configuration for JMAP service provider
    /// - Returns: `JMAPClient` with an authenticated ``Session`` already started
    public static func session(_ server: Server) async throws -> Self {
        let client: Self = Self(server)
        try await client.session()  // Start session
        return client
    }

    public let server: Server

    public func thread(for email: Email) async throws -> [Email] {
        if let session {
            guard let id: String = session.accounts.keys.first else {
                throw JMAPError.method(.accountNotFound)
            }
            guard
                let response: MethodGetResponse = try await URLSession.shared.jmapAPI(
                    [
                        Thread.GetMethod(
                            id,
                            ids: [
                                email.threadID
                            ])
                    ], url: session.apiURL, authorization: server.authorization!
                ).first as? MethodGetResponse
            else {
                throw URLError(.cannotDecodeContentData)
            }
            let threads: [JMAP.Thread] = try response.decode([JMAP.Thread].self)
            guard let ids: [String] = threads.first?.emailIDs,
                !ids.isEmpty
            else {
                throw URLError(.cannotDecodeContentData)
            }
            return try await emails(ids)
        } else {
            try await session()
            return try await thread(for: email)
        }
    }

    public func emails(in mailbox: Mailbox) async throws -> [Email] {
        if let session {
            guard let id: String = session.accounts.keys.first else {
                throw JMAPError.method(.accountNotFound)
            }
            logger?.debug("Querying emails in mailbox \(mailbox.name ?? mailbox.id)")
            guard
                let response: MethodQueryResponse = try await URLSession.shared.jmapAPI(
                    [
                        Email.QueryMethod(id, filter: .inMailbox(mailbox.id), extraCapabilities: extraCapabilities)
                    ], url: session.apiURL, authorization: server.authorization!
                ).first as? MethodQueryResponse
            else {
                throw JMAPError.underlying(URLError(.cannotDecodeContentData))
            }
            logger?.info("Query returned \(response.ids.count) email IDs (total: \(response.total))")
            return try await emails(response.ids)
        } else {
            try await session()
            return try await emails(in: mailbox)
        }
    }

    public func searchEmails(in mailbox: Mailbox, query: String) async throws -> [Email] {
        if let session {
            guard let id: String = session.accounts.keys.first else {
                throw JMAPError.method(.accountNotFound)
            }
            logger?.debug("Searching emails in mailbox \(mailbox.name ?? mailbox.id) for: \(query)")
            let filter = Filter([
                Email.Condition.inMailbox(mailbox.id),
                Email.Condition.text(query)
            ], operator: .and)
            guard
                let response: MethodQueryResponse = try await URLSession.shared.jmapAPI(
                    [
                        Email.QueryMethod(id, filter: filter, calculateTotal: true, extraCapabilities: extraCapabilities)
                    ], url: session.apiURL, authorization: server.authorization!
                ).first as? MethodQueryResponse
            else {
                throw JMAPError.underlying(URLError(.cannotDecodeContentData))
            }
            logger?.info("Search returned \(response.ids.count) email IDs (total: \(response.total))")
            guard !response.ids.isEmpty else { return [] }
            return try await emails(response.ids)
        } else {
            try await session()
            return try await searchEmails(in: mailbox, query: query)
        }
    }

    public func emails(_ ids: [String], configuration: Email.GetMethod.Configuration? = nil) async throws -> [Email] {
        if let session {
            guard let id: String = session.accounts.keys.first else {
                throw JMAPError.method(.accountNotFound)
            }
            guard
                let response: MethodGetResponse = try await URLSession.shared.jmapAPI(
                    [
                        Email.GetMethod(id, ids: ids, configuration: configuration, extraCapabilities: extraCapabilities)
                    ], url: session.apiURL, authorization: server.authorization!
                ).first as? MethodGetResponse
            else {
                throw URLError(.cannotDecodeContentData)
            }
            return try response.decode([Email].self)
        } else {
            try await session()
            return try await emails(ids, configuration: configuration)
        }
    }

    public func mailboxes() async throws -> [Mailbox] {
        if let session {
            guard let id: String = session.accounts.keys.first else {
                throw JMAPError.method(.accountNotFound)
            }
            logger?.debug("Fetching mailboxes for account \(id)")
            guard
                let response: MethodGetResponse = try await URLSession.shared.jmapAPI(
                    [
                        Mailbox.GetMethod(id)
                    ], url: session.apiURL, authorization: server.authorization!
                ).first as? MethodGetResponse
            else {
                throw JMAPError.underlying(URLError(.cannotDecodeContentData))
            }
            let mailboxes = try response.decode([Mailbox].self)
            logger?.info("Fetched \(mailboxes.count) mailboxes")
            return mailboxes
        } else {
            try await session()
            return try await mailboxes()
        }
    }

    @discardableResult public func session() async throws -> Session {
        logger?.info("Starting JMAP session: host=\(self.server.host), port=\(self.server.port), auth=\(self.server.authorization?.label ?? "none"), empty=\(self.server.authorization?.isEmpty ?? true)")
        do {
            let session: Session = try await URLSession.shared.jmapSession(server: server)
            self.session = session
            logger?.info("Session established: user=\(session.username), accounts=\(session.accounts.count), apiURL=\(session.apiURL)")
            return session
        } catch {
            logger?.error("Session failed: \(error)")
            throw error
        }
    }

    required public init(
        _ server: Server,
        logger: Logger? = Logger(subsystem: "net.thunderbird", category: "JMAP")
    ) {
        self.server = server
        self.logger = logger
    }

    private(set) var session: Session?
    private let logger: Logger?

    /// Extra capabilities to include in `using` based on what the session advertises.
    private var extraCapabilities: [Capability.Key] {
        var caps: [Capability.Key] = []
        if session?.capabilities[.mailIndexAI] != nil {
            caps.append(.mailIndexAI)
        }
        return caps
    }
}

extension Filter {
    static func inMailbox(_ id: String) -> Self {
        Self([
            Email.Condition.inMailbox(id)
        ])
    }
}
