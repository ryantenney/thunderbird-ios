import NIOIMAPCore

public typealias FetchAttribute = NIOIMAPCore.FetchAttribute

extension [FetchAttribute] {

    // Add supported fetch attributes according to set of server capabilities
    static func extended(_ capabilities: Set<Capability>) -> Self {
        Array(Set(capabilities.flatMap { extended($0) }))
    }

    // Add supported fetch attributes according to server capability
    static func extended(_ capability: Capability) -> Self {
        switch capability {
        case .gmailExtensions:
            [
                .gmailLabels,
                .gmailMessageID,
                .gmailThreadID
            ]
        case .objectID:
            [
                .emailID,
                .threadID
            ]
        default: []
        }
    }

    // Standard set of fetch attributes supported by all IMAP4 servers
    public static var standard: Self {
        [
            .envelope,
            .flags,
            .uid
        ]
    }

    // Filter unsupported attributes according to server capabilities
    func filtered(_ capabilities: Set<Capability>) -> Self {
        filter { attribute in
            switch attribute {
            case .emailID, .threadID: capabilities.contains(.objectID)
            case .gmailLabels, .gmailMessageID, .gmailThreadID: capabilities.contains(.gmailExtensions)
            case .preview: capabilities.contains(.preview)
            default: true
            }
        }
    }
}
