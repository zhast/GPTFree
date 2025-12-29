//
//  SlidingSidebarView.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import SwiftUI
import FoundationModels

struct SlidingSidebarView: View {
    @Binding var isShowing: Bool
    @EnvironmentObject var conversationStore: ConversationStore
    @State private var conversationToRename: Conversation?
    @State private var renameText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Chats")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button {
                    _ = conversationStore.createNewConversation()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 18, height: 27)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Conversation list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(conversationStore.conversations) { conversation in
                        let isSelected = conversation.id == conversationStore.currentConversationId

                        SidebarConversationRow(
                            conversation: conversation,
                            isSelected: isSelected,
                            onRename: {
                                renameText = conversation.title
                                conversationToRename = conversation
                            },
                            onGenerateTitle: {
                                Task {
                                    await generateTitle(for: conversation)
                                }
                            },
                            onDelete: {
                                Task {
                                    await conversationStore.deleteConversation(conversation.id)
                                }
                            }
                        )
                        .padding(.trailing, 4)
                        .onTapGesture {
                            conversationStore.selectConversation(conversation.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .contentMargins(.trailing, 4)

            Spacer()
        }
        .clipped()
        .background(.ultraThinMaterial)
        .sheet(item: $conversationToRename) { conversation in
            RenameConversationView(
                text: $renameText,
                onSave: {
                    conversationStore.updateTitle(renameText, for: conversation.id)
                    conversationToRename = nil
                },
                onCancel: {
                    conversationToRename = nil
                }
            )
        }
    }

    private func generateTitle(for conversation: Conversation) async {
        let persistence = PersistenceService.shared

        do {
            let messages = try await persistence.loadMessages(for: conversation.id)
            guard messages.count >= 1 else { return }

            let transcript = messages.prefix(6).map { msg in
                "\(msg.fromUser ? "User" : "Assistant"): \(msg.text)"
            }.joined(separator: "\n")

            let instructions = """
                Generate a very short title (2-5 words) that summarizes this conversation.
                Respond with ONLY the title, no quotes, no punctuation at the end.
                Examples of good titles: "Swift async await help", "Recipe for pasta", "Math homework help"
                """

            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: transcript)
            let title = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            if !title.isEmpty && title.count <= 50 {
                conversationStore.updateTitle(title, for: conversation.id)
            }
        } catch {
            print("Failed to generate title: \(error)")
        }
    }
}

struct SidebarConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    var onRename: (() -> Void)?
    var onGenerateTitle: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        Text(conversation.title)
            .font(.body)
            .foregroundColor(isSelected ? .primary : .secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.clear)
                        .glassEffect(.regular.tint(Color.accentColor), in: .rect(cornerRadius: 10))
                }
            }
            .contextMenu {
                Button {
                    onRename?()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button {
                    onGenerateTitle?()
                } label: {
                    Label("Generate Title", systemImage: "sparkles")
                }

                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } preview: {
                Text(conversation.title)
                    .font(.body)
                    .lineLimit(1)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
            }
    }
}

struct RenameConversationView: View {
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $text)
            }
            .navigationTitle("Rename Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SlidingSidebarView(isShowing: .constant(true))
        .environmentObject(ConversationStore())
        .frame(width: 300)
}
