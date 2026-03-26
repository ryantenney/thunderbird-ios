//
//  TempEmailModel.swift
//  Thunderbird
//
//  Created by Ashley Soucar on 12/5/25.
//

import Foundation

/// A protocol-agnostic email model for display in the UI.
/// Can be constructed from JMAP Email or (later) IMAP Message data.
struct DisplayEmail: Hashable, Identifiable {
    let id: String
    let sender: String
    let senderEmail: String
    let subject: String
    let preview: String
    let date: Date
    let recipients: [String]
    let isRead: Bool
    let hasAttachment: Bool
    let threadId: String?
    /// HTML body content, populated lazily when the user opens the email.
    var htmlBody: String?

    // MARK: AI Analysis
    var aiSummary: String? = nil
    var aiCategories: [String]? = nil
    var aiImportance: Double? = nil
    var aiSentiment: String? = nil
    var aiRequiresAction: Bool? = nil
    var aiActionItems: [AIActionItem]? = nil
    var aiKeyDates: [AIKeyDate]? = nil
}

struct AIActionItem: Hashable {
    let description: String
    let deadline: String?
}

struct AIKeyDate: Hashable {
    let date: String
    let description: String
}

import SwiftData
@Model
class TempEmail {

    var senderText: String
    var headerText: String
    var bodyText: String
    var dateSent: Date
    var uuid: UUID
    var recipients: [String]
    var attachments: [Data]!

    // For alignment, bool check likely not final
    var unread: Bool
    var newEmail: Bool
    var isThread: Bool
    var pinned: Bool

    init(
        sender: String,
        recipients: [String],
        headerText: String,
        bodyText: String,
        dateSent: Date,
        unread: Bool,
        newEmail: Bool,
        attachments: [Data]!,
        isThread: Bool,
        pinned: Bool
    ) {
        self.senderText = sender
        self.headerText = headerText
        self.bodyText = bodyText
        self.dateSent = dateSent
        self.unread = unread
        self.newEmail = newEmail
        self.attachments = attachments
        self.isThread = isThread
        self.uuid = UUID()
        self.recipients = recipients
        self.pinned = pinned
    }

    @MainActor static let sampleData = [
        TempEmail(
            sender: "Sender1",
            recipients: ["Rhea Thunderbird"],
            headerText: "Email one",
            bodyText: "This is some nice long text",
            dateSent: Date(),
            unread: true,
            newEmail: true,
            attachments: nil,
            isThread: false,
            pinned: false
        ),
        TempEmail(
            sender: "Sender1",
            recipients: ["Rhea Thunderbird"],
            headerText: "Email two",
            bodyText: "This is some nice long text",
            dateSent: Date(timeIntervalSinceNow: -6000),
            unread: true,
            newEmail: false,
            attachments: nil,
            isThread: false,
            pinned: true
        ),
        TempEmail(
            sender: "Sender2",
            recipients: ["Rhea Thunderbird"],
            headerText: "Email three with a longer set of text",
            bodyText: "This is some nice long text",
            dateSent: Date(timeIntervalSinceNow: -6200),
            unread: false,
            newEmail: false,
            attachments: nil,
            isThread: true,
            pinned: false
        ),
        TempEmail(
            sender: "Sender5",
            recipients: ["Rhea Thunderbird", "Roc Thunderbird Jr", "Roc Thunderbird", "Roc Thunderbird Sr"],
            headerText: "Email four with a longer set of text",
            bodyText: "This is some nice long text",
            dateSent: Date(timeIntervalSinceNow: -16000),
            unread: true,
            newEmail: false,
            attachments: nil,
            isThread: true,
            pinned: false
        ),
        TempEmail(
            sender: "Sender5",
            recipients: ["Rhea Thunderbird", "Roc Thunderbird"],
            headerText: "Email four with a longer set of text",
            bodyText: "This is some nice long text",
            dateSent: Date(timeIntervalSinceNow: -57000),
            unread: false,
            newEmail: false,
            attachments: [Data()],
            isThread: false,
            pinned: false
        )
    ]

}
