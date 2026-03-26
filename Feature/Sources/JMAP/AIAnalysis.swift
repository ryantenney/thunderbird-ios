import Foundation

/// AI-generated analysis for an email, provided by the `urn:ryantenney:params:jmap:mail-index-ai` JMAP extension.
public struct AIAnalysis: Decodable, Equatable, Sendable {
    public struct ActionItem: Decodable, Equatable, Sendable {
        public let description: String
        public let deadline: String?
    }

    public struct KeyDate: Decodable, Equatable, Sendable {
        public let date: String
        public let description: String
    }

    public let summary: String?
    public let categories: [String]?
    public let importance: Double?
    public let spamScore: Double?
    public let sentiment: String?
    public let requiresAction: Bool?
    public let actionItems: [ActionItem]?
    public let keyDates: [KeyDate]?
    public let provider: String
    public let model: String
}
