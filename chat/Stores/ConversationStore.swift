//
//  ConversationStore.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import SwiftUI
import Combine

@MainActor
class ConversationStore: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversationId: UUID?
    @Published var isLoading: Bool = false

    private let persistence = PersistenceService.shared

    var currentConversation: Conversation? {
        conversations.first { $0.id == currentConversationId }
    }

    /// Recent conversations excluding the current one (for context summaries)
    var recentConversations: [Conversation] {
        conversations
            .filter { $0.id != currentConversationId }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Run migration if needed
            if let migratedConversation = try await persistence.migrateIfNeeded() {
                conversations = [migratedConversation]
                currentConversationId = migratedConversation.id
                return
            }

            // Load existing conversations
            conversations = try await persistence.loadConversationsIndex()

            // Sort by most recent
            conversations.sort { $0.updatedAt > $1.updatedAt }

            // Select most recent if none selected
            if currentConversationId == nil, let first = conversations.first {
                currentConversationId = first.id
            }
        } catch {
            print("Failed to load conversations: \(error)")
        }
    }

    // MARK: - CRUD Operations

    func createNewConversation() -> Conversation {
        let conversation = Conversation()
        conversations.insert(conversation, at: 0)
        currentConversationId = conversation.id

        Task {
            try? await persistence.saveConversationsIndex(conversations)
        }

        return conversation
    }

    func selectConversation(_ id: UUID) {
        currentConversationId = id
    }

    func updateConversation(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
            Task {
                try? await persistence.saveConversationsIndex(conversations)
            }
        }
    }

    func deleteConversation(_ id: UUID) async {
        conversations.removeAll { $0.id == id }

        // Select another conversation if we deleted the current one
        if currentConversationId == id {
            currentConversationId = conversations.first?.id
        }

        do {
            try await persistence.deleteConversationMessages(for: id)
            try await persistence.saveConversationsIndex(conversations)
        } catch {
            print("Failed to delete conversation: \(error)")
        }
    }

    // MARK: - Message Count Updates

    func incrementMessageCount(for conversationId: UUID) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].messageCount += 1
            conversations[index].updatedAt = Date()

            Task {
                try? await persistence.saveConversationsIndex(conversations)
            }
        }
    }

    func updateTitle(_ title: String, for conversationId: UUID) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].title = title
            Task {
                try? await persistence.saveConversationsIndex(conversations)
            }
        }
    }

    func updateSummary(_ summary: ConversationSummary, for conversationId: UUID) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].summary = summary
            // Also update title from summary if still default
            if conversations[index].title == "New Chat" {
                conversations[index].title = summary.generatedTitle
            }
            Task {
                try? await persistence.saveConversationsIndex(conversations)
            }
        }
    }
}
