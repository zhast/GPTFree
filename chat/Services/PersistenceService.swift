//
//  PersistenceService.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import Foundation

actor PersistenceService {
    static let shared = PersistenceService()

    private let fileManager = FileManager.default

    // MARK: - Directory URLs

    private var documentsURL: URL {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if documents unavailable (should never happen on iOS)
            return fileManager.temporaryDirectory
        }
        return url
    }

    private var conversationsDirectoryURL: URL {
        documentsURL.appendingPathComponent("conversations", isDirectory: true)
    }

    private var conversationsIndexURL: URL {
        documentsURL.appendingPathComponent("conversations_index.json")
    }

    private var userMemoryURL: URL {
        documentsURL.appendingPathComponent("user_memory.json")
    }

    private var legacyMessagesURL: URL {
        documentsURL.appendingPathComponent("messages.json")
    }

    // MARK: - Initialization

    private init() {
        // Ensure conversations directory exists
        try? fileManager.createDirectory(at: conversationsDirectoryURL, withIntermediateDirectories: true)
    }

    // MARK: - Conversation Index

    func loadConversationsIndex() async throws -> [Conversation] {
        guard fileManager.fileExists(atPath: conversationsIndexURL.path) else {
            return []
        }
        let data = try Data(contentsOf: conversationsIndexURL)
        return try JSONDecoder().decode([Conversation].self, from: data)
    }

    func saveConversationsIndex(_ conversations: [Conversation]) async throws {
        let data = try JSONEncoder().encode(conversations)
        try data.write(to: conversationsIndexURL, options: [.atomicWrite, .completeFileProtection])
    }

    // MARK: - Individual Conversation Messages

    private func messagesURL(for conversationId: UUID) -> URL {
        conversationsDirectoryURL.appendingPathComponent("\(conversationId.uuidString).json")
    }

    func loadMessages(for conversationId: UUID) async throws -> [MessageItem] {
        let url = messagesURL(for: conversationId)
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([MessageItem].self, from: data)
    }

    func saveMessages(_ messages: [MessageItem], for conversationId: UUID) async throws {
        let data = try JSONEncoder().encode(messages)
        try data.write(to: messagesURL(for: conversationId), options: [.atomicWrite, .completeFileProtection])
    }

    func appendMessage(_ message: MessageItem, to conversationId: UUID) async throws {
        var messages = try await loadMessages(for: conversationId)
        messages.append(message)
        try await saveMessages(messages, for: conversationId)
    }

    func deleteConversationMessages(for conversationId: UUID) async throws {
        let url = messagesURL(for: conversationId)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - User Memory (Facts)

    func loadFacts() async throws -> [UserFact] {
        guard fileManager.fileExists(atPath: userMemoryURL.path) else {
            return []
        }
        let data = try Data(contentsOf: userMemoryURL)
        return try JSONDecoder().decode([UserFact].self, from: data)
    }

    func saveFacts(_ facts: [UserFact]) async throws {
        let data = try JSONEncoder().encode(facts)
        try data.write(to: userMemoryURL, options: [.atomicWrite, .completeFileProtection])
    }

    // MARK: - Migration

    /// Migrates legacy messages.json to the new multi-conversation format
    func migrateIfNeeded() async throws -> Conversation? {
        guard fileManager.fileExists(atPath: legacyMessagesURL.path) else {
            return nil
        }

        // Check if already migrated
        let existingConversations = try await loadConversationsIndex()
        if !existingConversations.isEmpty {
            return nil
        }

        // Load legacy messages
        let data = try Data(contentsOf: legacyMessagesURL)

        // Try to decode with the new format first (in case of partial migration)
        if let messages = try? JSONDecoder().decode([MessageItem].self, from: data),
           let firstMessage = messages.first {
            // Already in new format
            return nil
        }

        // Decode legacy format (without conversationId and timestamp)
        struct LegacyMessageItem: Codable {
            var id: UUID
            let text: String
            let fromUser: Bool
        }

        let legacyMessages = try JSONDecoder().decode([LegacyMessageItem].self, from: data)

        guard !legacyMessages.isEmpty else {
            return nil
        }

        // Create a new conversation for imported messages
        let conversationId = UUID()
        let now = Date()

        let conversation = Conversation(
            id: conversationId,
            title: "Imported Chat",
            createdAt: now,
            updatedAt: now,
            messageCount: legacyMessages.count
        )

        // Convert messages to new format
        let migratedMessages = legacyMessages.map { legacy in
            MessageItem(
                id: legacy.id,
                conversationId: conversationId,
                text: legacy.text,
                fromUser: legacy.fromUser,
                timestamp: now
            )
        }

        // Save in new format
        try await saveMessages(migratedMessages, for: conversationId)
        try await saveConversationsIndex([conversation])

        // Rename legacy file as backup
        let backupURL = documentsURL.appendingPathComponent("messages.json.backup")
        try? fileManager.moveItem(at: legacyMessagesURL, to: backupURL)

        return conversation
    }
}
