import Foundation
import NIOIMAPCore

public typealias BodyStructure = NIOIMAPCore.BodyStructure
public typealias SequenceNumber = NIOIMAPCore.SequenceNumber
public typealias SequenceSet = NIOIMAPCore.MessageIdentifierSetNonEmpty<SequenceNumber>
public typealias SectionSpecifier = NIOIMAPCore.SectionSpecifier
public typealias UID = NIOIMAPCore.UID
public typealias UIDRange = NIOIMAPCore.MessageIdentifierRange<UID>
public typealias UIDSet = NIOIMAPCore.UIDSetNonEmpty

public struct Message: Sendable {
    public enum Component: CustomStringConvertible, Equatable, Identifiable, Sendable {
        case bodyPart(SectionSpecifier, Data)
        case bodyStructure(BodyStructure, _ hasExtensionData: Bool = false)
        case emailID(String)
        case envelope(Envelope)
        case flags(Set<Flag>)
        case gmailLabels([GmailLabel])
        case gmailMessageID(UInt64)
        case gmailThreadID(UInt64)
        case internalDate(Date)
        case threadID(String)
        case uid(UID)

        public typealias BodyStructure = NIOIMAPCore.MessageAttribute.BodyStructure
        public typealias SectionSpecifier = NIOIMAPCore.SectionSpecifier

        // MARK: Equatable
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }

        // MARK: Identifiable
        public var id: String {
            switch self {
            case .bodyPart(let section, _): "bodyPart: \(section)"
            case .bodyStructure: "bodyStructure"
            case .emailID: "emailID"
            case .envelope: "envelope"
            case .flags: "flags"
            case .gmailLabels: "gmailLabels"
            case .gmailMessageID: "gmailMessageID"
            case .gmailThreadID: "gmailThreadID"
            case .internalDate: "internalDate"
            case .threadID: "threadID"
            case .uid: "uid"
            }
        }

        // MARK: CustomStringConvertible
        public var description: String {
            switch self {
            case .bodyPart(_, let data): "\(id) (\(data))"
            case .bodyStructure(let structure, let hasExtensionsData): "\(id): \(structure)\(hasExtensionsData ? " (hasExtensionsData)" : "")"
            case .emailID(let id), .threadID(let id): "\(self.id): \(id)"
            case .envelope(let envelope): "\(id): \(envelope)"
            case .flags(let flags): "\(id): \(flags)"
            case .gmailLabels(let labels): "\(id): \(labels)"
            case .gmailMessageID(let id), .gmailThreadID(let id): "\(self.id): \(id)"
            case .internalDate(let date): "\(id): \(date)"
            case .uid(let uid): "\(id): \(uid)"
            }
        }
    }

    public let components: [Component]

    public init(components: [Component]) {
        self.components = components
    }
}

public typealias MessageSet = [SequenceNumber: Message]

extension MessageSet {

    /// Array of ``Message`` ordered by ascending ``SequenceNumber``
    public var messages: [Message] {
        var messages: [Message] = []
        for key in keys.sorted() {
            messages.append(self[key]!)
        }
        return messages
    }
}

extension [Message.Component] {
    var uid: UID? {
        compactMap { component in
            switch component {
            case .uid(let uid): uid
            default: nil
            }
        }.first
    }
}

extension Message.Component {
    // Shared convenience decoder/mapper
    // Used by `FetchHandler`, `IdleHandler` and `NoopHandler`
    init?(_ attribute: MessageAttribute) {
        switch attribute {
        case .body(let structure, let hasExtensionData):
            self = .bodyStructure(structure, hasExtensionData)
        case .emailID(let emailID):
            self = .emailID(String(emailID))
        case .envelope(let envelope):
            self = .envelope(Envelope(envelope))
        case .flags(let flags):
            self = .flags(Set(flags))
        case .gmailLabels(let labels):
            self = .gmailLabels(labels)
        case .gmailMessageID(let id):
            self = .gmailMessageID(id)
        case .gmailThreadID(let id):
            self = .gmailThreadID(id)
        case .internalDate(let serverMessageDate):
            guard let date: Date = try? Date(serverMessageDate: serverMessageDate) else {
                return nil
            }
            self = .internalDate(date)
        case .threadID(let threadID):
            guard let threadID: String = String(threadID: threadID) else {
                return nil
            }
            self = .threadID(threadID)
        case .uid(let uid):
            self = .uid(uid)
        default:
            return nil
        }
    }
}

private extension String {
    init?(threadID: ThreadID?) {
        guard let threadID else {
            return nil
        }
        self = Self(threadID)
    }
}
