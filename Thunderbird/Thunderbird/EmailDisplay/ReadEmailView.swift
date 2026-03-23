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
