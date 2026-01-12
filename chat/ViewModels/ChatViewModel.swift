//
//  ChatViewModel.swift
//  chat
//
//  Created by Steven Zhang on 11/13/25.
//

import SwiftUI
import Combine
import FoundationModels

@MainActor
class ChatViewModel: ObservableObject {

    @Published var messages: [MessageItem] = []
    @Published var isResponding: Bool = false
    @Published var memoryUpdateMessage: String?

    let conversationId: UUID
    private let persistence = PersistenceService.shared
    private let factExtraction = FactExtractionService.shared

    init(conversationId: UUID) {
        self.conversationId = conversationId
    }

    // MARK: - Loading

    func loadMessages() async {
        do {
            messages = try await persistence.loadMessages(for: conversationId)
        } catch {
            print("Failed to load messages: \(error)")
        }
    }

    // MARK: - Sending Messages

    private let maxMessageLength = 10000 // Prevent extremely long messages

    func sendMessage(_ text: String, conversationStore: ConversationStore, memoryStore: MemoryStore) async {
        guard !text.isEmpty else { return }

        // Truncate extremely long messages to prevent memory/LLM issues
        let messageText = String(text.prefix(maxMessageLength))

        // Create and append user message
        let userMessage = MessageItem(conversationId: conversationId, text: messageText, fromUser: true)
        messages.append(userMessage)

        // Save and update conversation
        await saveAndUpdateConversation(conversationStore: conversationStore)

        // Generate AI reply
        await sendReply(conversationStore: conversationStore, memoryStore: memoryStore)

        // Extract facts in background (non-blocking)
        Task {
            await extractFactsInBackground(from: messageText, memoryStore: memoryStore)
        }
    }

    private func extractFactsInBackground(from userMessage: String, memoryStore: MemoryStore) async {
        #if DEBUG
        print("[ChatVM] Starting background fact extraction for: \(userMessage)")
        #endif

        do {
            let extractedFacts = try await factExtraction.extractFactsFromMessage(
                userMessage,
                conversationId: conversationId
            )

            #if DEBUG
            print("[ChatVM] Extracted \(extractedFacts.count) facts")
            #endif

            if !extractedFacts.isEmpty {
                // Add facts to memory store (skip duplicates)
                var addedCount = 0
                for fact in extractedFacts {
                    // Check for duplicates before adding
                    let isDupe = await factExtraction.isDuplicate(fact.content, existingFacts: memoryStore.facts)
                    if isDupe {
                        #if DEBUG
                        print("[ChatVM] Skipping duplicate fact: \(fact.content)")
                        #endif
                        continue
                    }

                    #if DEBUG
                    print("[ChatVM] Adding fact: \(fact.content)")
                    #endif
                    memoryStore.addFact(fact)
                    addedCount += 1
                }

                // Show notification only if we actually added something
                guard addedCount > 0 else { return }
                memoryUpdateMessage = "Saved \(addedCount) \(addedCount == 1 ? "memory" : "memories")"

                // Auto-dismiss after 3 seconds
                try? await Task.sleep(for: .seconds(3))
                memoryUpdateMessage = nil
            }
        } catch {
            print("[ChatVM] Background fact extraction failed: \(error)")
        }
    }

    private func sendReply(conversationStore: ConversationStore, memoryStore: MemoryStore) async {
        isResponding = true
        defer { isResponding = false }

        let availability = AppleIntelligenceAvailability.effectiveAvailability(system: SystemLanguageModel.default.availability)
        guard case .available = availability else {
            let errorText: String
            switch availability {
            case .unavailable(.deviceNotEligible):
                errorText = "This device can’t use Apple Intelligence, so I can’t generate replies."
            case .unavailable(.appleIntelligenceNotEnabled):
                errorText = "Apple Intelligence is turned off. Turn it on in Settings to use chat."
            case .unavailable(.modelNotReady):
                errorText = "Apple Intelligence is still downloading or preparing. Try again in a few minutes."
            case .unavailable:
                errorText = "Apple Intelligence isn’t available right now."
            default:
                errorText = "Apple Intelligence isn’t available right now."
            }

            let aiMessage = MessageItem(conversationId: conversationId, text: errorText, fromUser: false)
            messages.append(aiMessage)
            await saveAndUpdateConversation(conversationStore: conversationStore)
            return
        }

        // Build the 4-layer context prompt
        let prompt = assembleContext(
            conversation: conversationStore.currentConversation,
            recentConversations: conversationStore.recentConversations,
            facts: memoryStore.factsForContext
        )

        #if DEBUG
        print("[ChatVM] === CONTEXT SENT TO MODEL ===")
        print(prompt)
        print("[ChatVM] === END CONTEXT ===")
        #endif

        let instructions = """
            You are a helpful, friendly assistant with memory of past conversations.

            Guidelines:
            - ALWAYS respond to the LAST user message in the conversation.
            - Be concise and conversational. No markdown formatting, bullet points, or headers.
            - Use the User Memory and Recent Conversations context to personalize responses.
            - Reference remembered facts naturally when relevant, but don't force them into every response.
            - Never say "would you like me to", "shall I", "let me know if you want me to" - just do it or answer directly.
            - Keep responses brief unless the user asks for detail.
            """

        let session = LanguageModelSession(instructions: instructions)

        do {
            let response = try await session.respond(to: prompt)

            // Append AI response
            let aiMessage = MessageItem(conversationId: conversationId, text: response.content, fromUser: false)
            messages.append(aiMessage)

            // Save and update conversation
            await saveAndUpdateConversation(conversationStore: conversationStore)

            // Auto-generate title if this is a new conversation
            if conversationStore.currentConversation?.title == "New Chat" && messages.count >= 2 {
                await generateTitleIfNeeded(conversationStore: conversationStore)
            }

        } catch let error as LanguageModelSession.GenerationError {
            // Handle specific generation errors
            let errorText: String
            switch error {
            case .guardrailViolation:
                errorText = "I can't respond to that due to content restrictions. Try rephrasing your question."
            case .exceededContextWindowSize:
                errorText = "The conversation is too long. Try starting a new chat."
            default:
                errorText = "Sorry, I couldn't process that request."
            }
            let errorMessage = MessageItem(conversationId: conversationId, text: errorText, fromUser: false)
            messages.append(errorMessage)
            await saveAndUpdateConversation(conversationStore: conversationStore)
        } catch {
            print("Error getting AI response: \(error)")
            let errorMessage = MessageItem(conversationId: conversationId, text: "Sorry, I couldn't process that request.", fromUser: false)
            messages.append(errorMessage)
            await saveAndUpdateConversation(conversationStore: conversationStore)
        }
    }

    // MARK: - Context Assembly (4-Layer System)

    // Token budget for context window
    // Apple's on-device model has 4096 total tokens (input + output combined)
    // Reserve ~1000 tokens for the model's response
    private let totalTokenBudget = 4096
    private let reservedForOutput = 1000
    private var inputTokenBudget: Int { totalTokenBudget - reservedForOutput }
    private let charsPerToken = 4 // Rough estimate for English text

    private func estimateTokens(_ text: String) -> Int {
        // Round up to avoid underestimating (prevents context overflow)
        return (text.count + charsPerToken - 1) / charsPerToken
    }

    private func assembleContext(conversation: Conversation?, recentConversations: [Conversation], facts: [UserFact]) -> String {
        var contextParts: [String] = []
        var usedTokens = 0

        // Layer 1: Session Metadata
        let sessionMetadata = """
            [Session Info]
            Date: \(Date().formatted(date: .long, time: .shortened))
            Conversation: \(conversation?.title ?? "New Chat")
            """
        contextParts.append(sessionMetadata)
        usedTokens += estimateTokens(sessionMetadata)

        // Layer 2: User Memory (facts)
        if !facts.isEmpty {
            var memorySection = "[User Memory]\n"
            for fact in facts.prefix(15) {
                memorySection += "- \(fact.category.rawValue): \(fact.content)\n"
            }
            contextParts.append(memorySection)
            usedTokens += estimateTokens(memorySection)
        }

        // Layer 3: Recent Conversations Summary
        let conversationsWithSummaries = recentConversations.filter { $0.summary != nil }
        if !conversationsWithSummaries.isEmpty {
            var recentSection = "[Recent Conversations]\n"
            for conv in conversationsWithSummaries.prefix(5) {
                if let summary = conv.summary {
                    recentSection += "- \"\(summary.generatedTitle)\": \(summary.summaryText)\n"
                }
            }
            contextParts.append(recentSection)
            usedTokens += estimateTokens(recentSection)
        }

        // Layer 4: Current Conversation Messages (token-based sliding window)
        // Fill remaining budget with as many recent messages as will fit
        let remainingTokenBudget = inputTokenBudget - usedTokens
        var currentSection = "[Current Conversation]\n"
        var messageTexts: [String] = []
        var messageTokens = estimateTokens(currentSection)

        // Start from most recent and work backwards
        var isLatest = true
        for message in messages.reversed() {
            let sender = message.fromUser ? "User" : "Assistant"
            // Mark the latest user message
            let prefix = (isLatest && message.fromUser) ? "[RESPOND TO THIS] " : ""
            let messageText = "\(prefix)\(sender): \(message.text)\n"
            let messageTokenCount = estimateTokens(messageText)

            if messageTokens + messageTokenCount <= remainingTokenBudget {
                messageTexts.insert(messageText, at: 0) // Insert at beginning to maintain order
                messageTokens += messageTokenCount
                if message.fromUser { isLatest = false }
            } else {
                break // No more room
            }
        }

        currentSection += messageTexts.joined()
        contextParts.append(currentSection)

        return contextParts.joined(separator: "\n\n")
    }

    // MARK: - Title Generation

    private func generateTitleIfNeeded(conversationStore: ConversationStore) async {
        guard messages.count >= 2 else { return }

        // Build a brief transcript of the conversation
        let transcript = messages.prefix(6).map { msg in
            "\(msg.fromUser ? "User" : "Assistant"): \(msg.text)"
        }.joined(separator: "\n")

        let instructions = """
            Generate a very short title (2-5 words) that summarizes this conversation.
            Respond with ONLY the title, no quotes, no punctuation at the end.
            Examples of good titles: "Swift async await help", "Recipe for pasta", "Math homework help"
            """

        let session = LanguageModelSession(instructions: instructions)

        do {
            let response = try await session.respond(to: transcript)
            let title = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Only update if we got a reasonable title
            if !title.isEmpty && title.count <= 50 {
                conversationStore.updateTitle(title, for: conversationId)
            }
        } catch {
            // Fallback to first few words if LLM fails
            if let firstUserMessage = messages.first(where: { $0.fromUser }) {
                let words = firstUserMessage.text.split(separator: " ").prefix(5)
                let title = words.joined(separator: " ") + (firstUserMessage.text.split(separator: " ").count > 5 ? "..." : "")
                conversationStore.updateTitle(title, for: conversationId)
            }
        }
    }

    // MARK: - Persistence

    private func saveAndUpdateConversation(conversationStore: ConversationStore) async {
        do {
            try await persistence.saveMessages(messages, for: conversationId)
            conversationStore.incrementMessageCount(for: conversationId)
        } catch {
            print("Failed to save messages: \(error)")
        }
    }

    func clearMessages() {
        messages.removeAll()
        Task {
            try? await persistence.saveMessages([], for: conversationId)
        }
    }

    // MARK: - Edit & Delete Messages

    func deleteMessage(_ message: MessageItem) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }

        // Remove this message and all subsequent messages
        messages = Array(messages.prefix(index))

        Task {
            try? await persistence.saveMessages(messages, for: conversationId)
        }
    }

    func updateMessage(_ message: MessageItem, newText: String, conversationStore: ConversationStore, memoryStore: MemoryStore) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }

        // Update the message text
        messages[index] = MessageItem(
            id: message.id,
            conversationId: message.conversationId,
            text: newText,
            fromUser: message.fromUser,
            timestamp: message.timestamp
        )

        // If it's a user message, remove all subsequent messages and regenerate
        if message.fromUser {
            // Remove all messages after this one
            messages = Array(messages.prefix(index + 1))

            Task {
                try? await persistence.saveMessages(messages, for: conversationId)
            }

            // Regenerate response
            Task {
                await sendReply(conversationStore: conversationStore, memoryStore: memoryStore)
            }
        } else {
            // For assistant messages, just save the edit
            Task {
                try? await persistence.saveMessages(messages, for: conversationId)
            }
        }
    }
}
