import Foundation
import UniformTypeIdentifiers

/// `Email` represents a single message, pre-decoded and modeled, no client-side MIME parsing required; part of [JMAP mail protocol.](https://jmap.io/spec-mail.html#emails)
public struct Email: Decodable, Equatable, Hashable, Identifiable, Sendable {
    public struct Address: CustomStringConvertible, Decodable, Equatable, Sendable {
        public let email: String
        public let name: String?

        init(_ email: String, name: String? = nil) {
            self.email = email
            self.name = name
        }

        // MARK: CustomStringConvertible
        public var description: String {
            !(name ?? "").isEmpty ? "\"\(name!)\" <\(email)>" : "\(email)"
        }
    }

    public struct AddressGroup: Decodable, Equatable {
        public let adresses: [Address]
        public let name: String?
    }

    public enum Keyword: String, CaseIterable, CustomStringConvertible, Sendable {
        case draft = "$draft"
        case seen = "$seen"
        case flagged = "$flagged"
        case answered = "$answered"
        case forwarded = "$forwarded"
        case phishing = "$phishing"
        case junk = "$junk"
        case notjunk = "$notjunk"

        // MARK: CaseIterable
        public static let allCases: [Self] = [
            .draft,
            .seen,
            .flagged,
            .answered
        ]

        // MARK: CustomStringConvertible
        public var description: String { rawValue }
    }

    public struct BodyPart: Decodable, Equatable, Sendable {
        public let partID: String?
        public let blobID: String?
        public let size: Int
        public let headers: [Header]?
        public let name: String?
        public let type: String
        public let charset: String?
        public let disposition: String?
        public let cid: String?
        public let language: [String]?
        public let location: String?
        public let subParts: [Self]?

        init(
            partID: String? = nil,
            blobID: String? = nil,
            size: Int,
            headers: [Header]? = nil,
            name: String? = nil,
            type: String,
            charset: String? = nil,
            disposition: String? = nil,
            cid: String? = nil,
            language: [String]? = nil,
            location: String? = nil,
            subParts: [Self]? = nil
        ) {
            self.partID = partID
            self.blobID = blobID
            self.size = max(size, 0)
            self.headers = headers
            self.name = name
            self.type = type
            self.charset = charset
            self.disposition = disposition
            self.cid = cid
            self.language = language
            self.location = location
            self.subParts = subParts
        }

        // MARK: Equatable
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.partID == rhs.partID && lhs.size == rhs.size && lhs.type == rhs.type
        }
    }

    public struct Header: Decodable, Sendable {

    }

    /// Decoded body content returned when `fetchHTMLBodyValues` or `fetchTextBodyValues` is requested.
    public struct BodyValue: Decodable, Sendable {
        public let value: String
        public let isEncodingProblem: Bool
        public let isTruncated: Bool

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decode(String.self, forKey: .value)
            isEncodingProblem = try container.decodeIfPresent(Bool.self, forKey: .isEncodingProblem) ?? false
            isTruncated = try container.decodeIfPresent(Bool.self, forKey: .isTruncated) ?? false
        }

        private enum CodingKeys: CodingKey {
            case value, isEncodingProblem, isTruncated
        }
    }

    public let blobID: String
    public let threadID: String
    public let mailboxIDs: [String: Bool]
    public let keywords: [String: Bool]
    public let size: Int
    public let receivedAt: Date?
    public let sentAt: Date?
    public let messageID: [String]?
    public let inReplyTo: [String]?
    public let references: [String]?
    public let sender: [Address]?
    public let from: [Address]?
    public let replyTo: [Address]?
    public let to: [Address]?
    public let cc: [Address]?
    public let bcc: [Address]?
    public let subject: String?
    public let bodyStructure: BodyPart?
    public let bodyValues: [String: BodyValue]
    public let textBody: [BodyPart]
    public let htmlBody: [BodyPart]
    public let attachments: [BodyPart]
    public let hasAttachment: Bool
    public let preview: String?

    /// HTML body content extracted from `bodyValues`, if available.
    public var htmlContent: String? {
        guard let part = htmlBody.first, let partID = part.partID else { return nil }
        return bodyValues[partID]?.value
    }

    /// Plain text body content extracted from `bodyValues`, if available.
    public var textContent: String? {
        guard let part = textBody.first, let partID = part.partID else { return nil }
        return bodyValues[partID]?.value
    }

    // MARK: Decodable
    public init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<Key> = try decoder.container(keyedBy: Key.self)
        id = try container.decode(String.self, forKey: .id)
        blobID = try container.decode(String.self, forKey: .blobId)
        threadID = try container.decode(String.self, forKey: .threadId)
        mailboxIDs = try container.decode([String: Bool].self, forKey: .mailboxIds)
        keywords = try container.decode([String: Bool].self, forKey: .keywords)
        size = try container.decode(Int.self, forKey: .size)
        receivedAt = try container.decodeIfPresent(Date.self, forKey: .receivedAt)
        sentAt = try container.decodeIfPresent(Date.self, forKey: .sentAt)
        messageID = try container.decodeIfPresent([String].self, forKey: .messageId)
        inReplyTo = try container.decodeIfPresent([String].self, forKey: .inReplyTo)
        references = try container.decodeIfPresent([String].self, forKey: .references)
        sender = try container.decodeIfPresent([Address].self, forKey: .sender)
        from = try container.decodeIfPresent([Address].self, forKey: .from)
        replyTo = try container.decodeIfPresent([Address].self, forKey: .replyTo)
        to = try container.decodeIfPresent([Address].self, forKey: .to)
        cc = try container.decodeIfPresent([Address].self, forKey: .cc)
        bcc = try container.decodeIfPresent([Address].self, forKey: .bcc)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        bodyStructure = try container.decodeIfPresent(BodyPart.self, forKey: .bodyStructure)
        bodyValues = try container.decodeIfPresent([String: BodyValue].self, forKey: .bodyValues) ?? [:]
        textBody = try container.decode([BodyPart].self, forKey: .textBody)
        htmlBody = try container.decode([BodyPart].self, forKey: .htmlBody)
        attachments = try container.decode([BodyPart].self, forKey: .attachments)
        hasAttachment = try container.decode(Bool.self, forKey: .hasAttachment)
        preview = try container.decode(String.self, forKey: .preview)
    }

    private enum Key: CodingKey {
        case blobId, threadId, mailboxIds, keywords, size, receivedAt, sentAt, messageId, inReplyTo, references, sender, from, replyTo, to, cc, bcc, subject, bodyStructure, bodyValues, textBody, htmlBody, attachments, hasAttachment, preview, id
    }

    // MARK: Equatable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: Identifiable
    public let id: String
}

extension Email {
    struct GetMethod: Method {
        struct Configuration {
            static var allBodyParts: Self {
                Configuration(
                    bodyProperties: BodyProperty.allCases,
                    fetchTextBodyValues: true,
                    fetchHTMLBodyValues: true,
                    fetchAllBodyValues: true
                )
            }

            let bodyProperties: [BodyProperty]?
            let fetchTextBodyValues: Bool
            let fetchHTMLBodyValues: Bool
            let fetchAllBodyValues: Bool
            let maxBodyValueBytes: Int

            init(
                bodyProperties: [BodyProperty]? = nil,
                fetchTextBodyValues: Bool = false,
                fetchHTMLBodyValues: Bool = false,
                fetchAllBodyValues: Bool = false,
                maxBodyValueBytes: Int = 0
            ) {
                self.bodyProperties = bodyProperties
                self.fetchTextBodyValues = fetchTextBodyValues
                self.fetchHTMLBodyValues = fetchHTMLBodyValues
                self.fetchAllBodyValues = fetchAllBodyValues
                self.maxBodyValueBytes = max(maxBodyValueBytes, 0)
            }
        }

        enum BodyProperty: String, CaseIterable, CustomStringConvertible {
            case partID = "partId", blobID = "blobId", size, headers, name, type, charset, disposition, cid, language, location, subParts

            // MARK: CustomStringConvertible
            var description: String { rawValue }
        }

        let configuration: Configuration?
        let ids: [String]

        init(_ accountID: String, ids: [String], configuration: Configuration? = nil, id: UUID = UUID()) throws {
            guard !accountID.isEmpty else {
                throw MethodError.accountNotFound
            }
            guard !ids.isEmpty else {
                throw MethodError.invalidArguments
            }
            self.accountID = accountID
            self.ids = ids
            self.configuration = configuration
            self.id = id
        }

        private var requestObject: [String: Any] {
            var object: [String: Any] = [
                "accountId": accountID,
                "ids": ids
            ]
            if let configuration {
                object["fetchTextBodyValues"] = configuration.fetchTextBodyValues
                object["fetchHTMLBodyValues"] = configuration.fetchHTMLBodyValues
                object["fetchAllBodyValues"] = configuration.fetchAllBodyValues
                object["maxBodyValueBytes"] = configuration.maxBodyValueBytes
                if let bodyProperties: [BodyProperty] = configuration.bodyProperties {
                    object["bodyProperties"] = bodyProperties.map { $0.rawValue }
                }
            }
            return object
        }

        // MARK: Method
        static let name: String = "\(prefix)get"
        let accountID: String
        let id: UUID

        var object: [Any] {
            [
                Self.name,
                requestObject,
                id.uuidString
            ]
        }
    }

    struct QueryMethod: Method {
        let filter: Filter?
        let collapseThreads: Bool
        let calculateTotal: Bool

        init(_ accountID: String, filter: Filter? = nil, collapseThreads: Bool = false, calculateTotal: Bool = false, id: UUID = UUID()) throws {
            guard !accountID.isEmpty else {
                throw MethodError.accountNotFound
            }
            self.accountID = accountID
            self.filter = filter
            self.collapseThreads = collapseThreads
            self.calculateTotal = calculateTotal
            self.id = id
        }

        private var query: [String: Any] {
            var query: [String: Any] = [
                "accountId": accountID,
                "collapseThreads": collapseThreads,
                "calculateTotal": calculateTotal
            ]
            if let filter {
                query["filter"] = filter.object
            }
            return query
        }

        // MARK: Method
        static let name: String = "\(prefix)query"
        let accountID: String
        let id: UUID

        var object: [Any] {
            [
                Self.name,
                query,
                id.uuidString
            ]
        }
    }

    static let prefix: String = "Email/"
}

extension Email {
    public enum Condition: Filter.Condition {
        case inMailbox(String)
        case inMailboxOtherThan([String])
        case before(Date)
        case after(Date)
        case minSize(Int)
        case maxSize(Int)
        case allInThreadHaveKeyword(String)
        case someInThreadHaveKeyword(String)
        case noneInThreadHaveKeyword(String)
        case hasKeyword(String)
        case notKeyword(String)
        case hasAttachment(Bool)
        case text(String)
        case from(String)
        case to(String)
        case cc(String)
        case bcc(String)
        case subject(String)
        case body(String)
        case header([String])

        // MARK: Filter.Condition
        public var key: String {
            switch self {
            case .inMailbox: "inMailbox"
            case .inMailboxOtherThan: "inMailboxOtherThan"
            case .before: "before"
            case .after: "after"
            case .minSize: "minSize"
            case .maxSize: "maxSize"
            case .allInThreadHaveKeyword: "allInThreadHaveKeyword"
            case .someInThreadHaveKeyword: "someInThreadHaveKeyword"
            case .noneInThreadHaveKeyword: "noneInThreadHaveKeyword"
            case .hasKeyword: "hasKeyword"
            case .notKeyword: "notKeyword"
            case .hasAttachment: "hasAttachment"
            case .text: "text"
            case .from: "from"
            case .to: "to"
            case .cc: "cc"
            case .bcc: "bcc"
            case .subject: "subject"
            case .body: "body"
            case .header: "header"
            }
        }

        public var value: Any {
            switch self {
            case .inMailbox(let string),
                .allInThreadHaveKeyword(let string),
                .someInThreadHaveKeyword(let string),
                .noneInThreadHaveKeyword(let string),
                .hasKeyword(let string),
                .notKeyword(let string),
                .text(let string),
                .from(let string),
                .to(let string),
                .cc(let string),
                .bcc(let string),
                .subject(let string),
                .body(let string):
                string
            case .inMailboxOtherThan(let strings),
                .header(let strings):
                strings
            case .before(let date),
                .after(let date):
                ISO8601DateFormatter().string(from: date)
            case .minSize(let bytes),
                .maxSize(let bytes):
                bytes
            case .hasAttachment(let bool): bool
            }
        }
    }
}
