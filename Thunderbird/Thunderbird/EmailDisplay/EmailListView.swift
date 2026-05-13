//
//  EmailListView.swift
//  Thunderbird
//
//  Created by Ashley Soucar on 10/20/25.
//

import SwiftUI
import Account

struct EmailListView: View {
    @Environment(Accounts.self) private var accounts: Accounts
    @Environment(\.openURL) private var openURL
    var emailService: EmailService
    @State private var searchText: String = ""

    func sortEmails() {
        //Not yet implemented
        AlertManager.shared.showAlert = true
        AlertManager.shared.alertTitle = "Sort Emails"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                if emailService.isLoading && emailService.displayedEmails.isEmpty {
                    VStack {
                        ProgressView("Loading emails…")
                            .padding()
                        Spacer()
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = emailService.error, emailService.displayedEmails.isEmpty {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                        Text("Failed to load emails")
                            .font(.headline)
                            .padding(.bottom, 4)
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task { await emailService.fetchInbox() }
                        }
                        .buttonBorderShape(.capsule)
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                        Spacer()
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let results = emailService.searchResults, results.isEmpty {
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                        Text("No results found")
                            .font(.headline)
                            .padding(.bottom, 4)
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if emailService.displayedEmails.isEmpty {
                    VStack {
                        Text("empty_inbox")
                            .padding(.bottom, 5)
                        Text("new_messages_will_appear")
                            .padding(.bottom, 10)
                        Button {

                        } label: {
                            Text("add_another_account")
                        }.buttonBorderShape(.capsule)
                            .buttonStyle(.bordered)
                            .foregroundStyle(.black)
                        Spacer()
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(emailService.displayedEmails) { email in
                        EmailCellView(email: email)
                            .listRowSeparator(.hidden)
                            .background {
                                NavigationLink(value: email) {
                                    EmptyView()
                                }.opacity(0)
                            }
                    }.listStyle(.plain)
                        .navigationDestination(for: DisplayEmail.self) { displayEmail in
                            ReadEmailView(displayEmail, emailService: emailService)
                        }
                        .scrollContentBackground(.hidden)
                        .refreshable {
                            await emailService.fetchInbox()
                        }
                        .overlay {
                            if emailService.isSearching {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                    .padding(.top, 20)
                            }
                        }
                }
                Button {
                    // Action
                } label: {
                    Image("compose")
                        .font(.title.weight(.regular))
                        .padding(.all, 12)
                        .padding(.leading, 5)
                        .background(Color(white: 0.9))
                        .foregroundColor(.muted)
                        .clipShape(Circle())
                }
                .background(.clear)
                .padding()
            }
            .navigationTitle("inbox_header")
            .searchable(text: $searchText, prompt: "Search emails")
            .task(id: searchText) {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    emailService.clearSearch()
                } else {
                    await emailService.searchEmails(query: searchText)
                }
            }
            .onChange(of: searchText) {
                if searchText.isEmpty {
                    emailService.clearSearch()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(
                            "date_sort_button",
                            action: {
                                sortEmails()
                            })
                        Button(
                            "read_status_sort_button",
                            action: {
                                sortEmails()
                            })
                        Button(
                            "has_attachments_sort_button",
                            action: {
                                sortEmails()
                            })
                    } label: {
                        Label("sort_button", systemImage: "line.3.horizontal.decrease", )
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(
                            "account_sign_out_button",
                            action: {
                                accounts.deleteAccounts()
                            })
                        Button(
                            "donation_support",
                            action: {
                                guard let url = URL(string: "https://www.thunderbird.net/en-US/donate/") else { return }
                                openURL(url)
                            })
                    } label: {
                        Label("options_button", systemImage: "ellipsis")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("settings_button", destination: FeatureFlagDebugView())
                }
            }
        }
        .task {
            await emailService.fetchInbox()
        }
    }
}

#Preview("Email List") {
    @Previewable @State var accounts: Accounts = Accounts()
    let previewAccount = Account(name: "Preview")
    EmailListView(emailService: EmailService(account: previewAccount))
        .environment(accounts)
}
