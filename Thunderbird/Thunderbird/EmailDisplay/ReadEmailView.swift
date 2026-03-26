//
//  ReadEmailView.swift
//  Thunderbird
//
//  Created by Ashley Soucar on 10/20/25.
//

import Account
import SwiftUI
import WebKit

struct ReadEmailView: View {
    private var email: DisplayEmail
    private var emailService: EmailService
    @State private var bodyContent: String?
    @State private var isLoadingBody: Bool = false

    init(_ email: DisplayEmail, emailService: EmailService) {
        self.email = email
        self.emailService = emailService
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(email.subject)
                        .font(.title3)
                    Spacer()
                    if email.hasAttachment {
                        Image(systemName: "paperclip").font(.caption)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading) {
                        SenderView(email.sender, email.date, email.recipients)

                        // AI Analysis card
                        if email.aiSummary != nil || email.aiCategories != nil {
                            AISummaryCard(email: email)
                                .padding(.top, 8)
                        }

                        // Action Items
                        if let items = email.aiActionItems, !items.isEmpty {
                            AIActionItemsView(items: items)
                                .padding(.top, 4)
                        }

                        // Key Dates
                        if let dates = email.aiKeyDates, !dates.isEmpty {
                            AIKeyDatesView(dates: dates)
                                .padding(.top, 4)
                        }

                        if isLoadingBody {
                            ProgressView("Loading email…")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else if let body = bodyContent {
                            WebView(htmlString: body).scaledToFill()
                        } else {
                            Text(email.preview)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                    }
                }

            }.padding()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            AlertManager.shared.showAlert = true
                            AlertManager.shared.alertTitle = "Archive"
                        }) {
                            Image(systemName: "archivebox")
                                .foregroundStyle(.foreground)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            AlertManager.shared.showAlert = true
                            AlertManager.shared.alertTitle = "More Options"
                        }) {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.foreground)
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: {
                            AlertManager.shared.showAlert = true
                            AlertManager.shared.alertTitle = "Reply"
                        }) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .foregroundStyle(.foreground)
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: {
                            AlertManager.shared.showAlert = true
                            AlertManager.shared.alertTitle = "Reply All"
                        }) {
                            Image(systemName: "arrowshape.turn.up.left.2")
                                .foregroundStyle(.foreground)
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: {
                            AlertManager.shared.showAlert = true
                            AlertManager.shared.alertTitle = "Trash"
                        }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.foreground)
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: {
                            AlertManager.shared.showAlert = true
                            AlertManager.shared.alertTitle = "Forward"
                        }) {
                            Image(systemName: "arrowshape.turn.up.right")
                                .foregroundStyle(.foreground)
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: {
                            AlertManager.shared.showAlert = true
                            AlertManager.shared.alertTitle = "More"
                        }) {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.foreground)
                        }
                    }
                }
        }
        .task {
            if let cached = email.htmlBody {
                bodyContent = cached
                return
            }
            isLoadingBody = true
            bodyContent = await emailService.fetchBody(for: email)
            isLoadingBody = false
        }
    }
}

struct AttachmentBlockView: View {
    init(_ attachments: [Data]) {
        self.attachments = attachments
    }
    private var attachments: [Data]
    var body: some View {
        VStack(alignment: .leading) {
            Text("^[\(attachments.count) attachment](inflect: true)")
                .font(.footnote)
            ForEach(attachments, id: \.self) { _ in
                SingleAttachment()
            }
        }

    }
}

struct SingleAttachment: View {
    init() {
        //Do Stuff
    }
    var body: some View {
        HStack {
            Image(systemName: "photo")
                .resizable()
                .frame(width: 56, height: 44)
                .foregroundStyle(.gray)
            VStack(alignment: .leading) {
                Text("rockFlying.png")
                Text("1.78 MB")
            }.font(.footnote)
        }
    }
}

struct WebView: UIViewRepresentable {
    let htmlString: String

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}

struct SenderView: View {
    init(_ sender: String, _ sentDate: Date, _ recipients: [String]) {
        self.sender = sender
        self.date = sentDate
        self.recipients = recipients
    }
    private var sender: String
    private var recipients: [String]
    private var date: Date
    @State private var showingAlert = false
    @State private var unimplementedFeatureName: String = ""

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(sender).font(.title3)
                }
                if !recipients.isEmpty {
                    HStack {
                        Text("To: \(recipients[0])")
                        if recipients.count > 1 {
                            Text("+\(recipients.count-1)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.accent)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(date, style: .date)
                    .font(.footnote)
                    .padding(.bottom, 4)
                Button(action: {
                    //Options
                    AlertManager.shared.showAlert = true
                    AlertManager.shared.alertTitle = "More Options"
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.foreground)
                }
            }

        }
    }
}

// MARK: - AI Summary Card

struct AISummaryCard: View {
    let email: DisplayEmail

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("AI Summary")
                    .font(.subheadline.bold())
                Spacer()
                if let importance = email.aiImportance {
                    ImportanceBadge(importance: importance)
                }
                if let sentiment = email.aiSentiment {
                    SentimentBadge(sentiment: sentiment)
                }
            }

            if let summary = email.aiSummary {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            if let categories = email.aiCategories, !categories.isEmpty {
                HStack(spacing: 4) {
                    ForEach(categories, id: \.self) { category in
                        CategoryPill(category)
                    }
                }
            }

            if email.aiRequiresAction == true {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Action required")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct ImportanceBadge: View {
    let importance: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: importance >= 0.8 ? "flame.fill" : "flame")
                .font(.caption)
            Text(label)
                .font(.caption2)
        }
        .foregroundStyle(color)
    }

    private var label: String {
        if importance >= 0.8 { return "High" }
        if importance >= 0.5 { return "Normal" }
        return "Low"
    }

    private var color: Color {
        if importance >= 0.8 { return .orange }
        if importance >= 0.5 { return .secondary }
        return .gray
    }
}

struct SentimentBadge: View {
    let sentiment: String

    var body: some View {
        Text(icon)
            .font(.caption)
    }

    private var icon: String {
        switch sentiment {
        case "positive": return "+"
        case "negative": return "-"
        default: return ""
        }
    }
}

// MARK: - AI Action Items

struct AIActionItemsView: View {
    let items: [AIActionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .foregroundStyle(.blue)
                Text("Action Items")
                    .font(.subheadline.bold())
            }

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.description)
                            .font(.body)
                        if let deadline = item.deadline {
                            Text(deadline)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - AI Key Dates

struct AIKeyDatesView: View {
    let dates: [AIKeyDate]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .foregroundStyle(.blue)
                Text("Key Dates")
                    .font(.subheadline.bold())
            }

            ForEach(Array(dates.enumerated()), id: \.offset) { _, keyDate in
                HStack(alignment: .top, spacing: 8) {
                    Text(keyDate.date)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(keyDate.description)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    let email = DisplayEmail(
        id: "preview-1",
        sender: "Sender@sender.com",
        senderEmail: "sender@sender.com",
        subject: "This is the subject line of the email",
        preview: "This is a preview of the email content…",
        date: Date(),
        recipients: ["Rhea Thunderbird", "Roc"],
        isRead: false,
        hasAttachment: true,
        threadId: nil,
        htmlBody: """
            <html><body>
            <h2>This is a test email</h2>
            <p>Its doing its best to model how an email might look</p>
            </body></html>
            """
    )
    let previewAccount = Account(name: "Preview")
    ReadEmailView(email, emailService: EmailService(account: previewAccount))
}
