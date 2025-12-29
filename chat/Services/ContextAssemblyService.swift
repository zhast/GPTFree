//
//  ContextAssemblyService.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import Foundation

/// Token budget configuration for context assembly
struct ContextBudget {
    let totalTokens: Int
    let sessionMetadataTokens: Int
    let userMemoryTokens: Int
    let recentConversationsTokens: Int
    let currentMessagesTokens: Int

    static let standard = ContextBudget(
        totalTokens: 4000,
        sessionMetadataTokens: 100,
        userMemoryTokens: 400,
        recentConversationsTokens: 400,
        currentMessagesTokens: 3100
    )
}

/// Assembled context ready for the LLM
struct AssembledContext {
    let sessionMetadata: String
    let userMemory: String
    let recentConversations: String
    let currentMessages: String
    let estimatedTokens: Int

    var fullPrompt: String {
        [sessionMetadata, userMemory, recentConversations, currentMessages]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}

class ContextAssemblyService {
    static let shared = ContextAssemblyService()

    private let budget: ContextBudget

    init(budget: ContextBudget = .standard) {
        self.budget = budget
    }

    /// Assembles context from all 4 layers
    func assembleContext(
        conversation: Conversation?,
        messages: [MessageItem],
        facts: [UserFact],
        recentConversations: [Conversation]
    ) -> AssembledContext {
        var totalTokens = 0

        // Layer 1: Session Metadata
        let sessionMetadata = buildSessionMetadata(conversation: conversation)
        totalTokens += estimateTokens(sessionMetadata)

        // Layer 2: User Memory
        let userMemory = buildUserMemory(facts: facts, budget: budget.userMemoryTokens)
        totalTokens += estimateTokens(userMemory)

        // Layer 3: Recent Conversations
        let recentConvs = buildRecentConversations(conversations: recentConversations, budget: budget.recentConversationsTokens)
        totalTokens += estimateTokens(recentConvs)

        // Layer 4: Current Messages (uses remaining budget)
        let remainingBudget = budget.totalTokens - totalTokens
        let currentMsgs = buildCurrentMessages(messages: messages, budget: max(remainingBudget, budget.currentMessagesTokens))

        return AssembledContext(
            sessionMetadata: sessionMetadata,
            userMemory: userMemory,
            recentConversations: recentConvs,
            currentMessages: currentMsgs,
            estimatedTokens: totalTokens + estimateTokens(currentMsgs)
        )
    }

    // MARK: - Layer Builders

    private func buildSessionMetadata(conversation: Conversation?) -> String {
        """
        [Session Info]
        Date: \(Date().formatted(date: .long, time: .shortened))
        Conversation: \(conversation?.title ?? "New Chat")
        """
    }

    private func buildUserMemory(facts: [UserFact], budget: Int) -> String {
        guard !facts.isEmpty else { return "" }

        // Sort by priority: verified first, then by confidence
        let sortedFacts = facts.sorted { fact1, fact2 in
            if fact1.isUserVerified != fact2.isUserVerified {
                return fact1.isUserVerified
            }
            return fact1.confidence > fact2.confidence
        }

        var result = "[User Memory]\n"
        var currentTokens = estimateTokens(result)

        for fact in sortedFacts {
            let factLine = "- \(fact.category.rawValue): \(fact.content)\n"
            let lineTokens = estimateTokens(factLine)

            if currentTokens + lineTokens > budget {
                break
            }

            result += factLine
            currentTokens += lineTokens
        }

        return result
    }

    private func buildRecentConversations(conversations: [Conversation], budget: Int) -> String {
        let conversationsWithSummaries = conversations.filter { $0.summary != nil }
        guard !conversationsWithSummaries.isEmpty else { return "" }

        var result = "[Recent Conversations]\n"
        var currentTokens = estimateTokens(result)

        for conversation in conversationsWithSummaries.prefix(5) {
            guard let summary = conversation.summary else { continue }

            let convLine = "- \"\(summary.generatedTitle)\": \(summary.summaryText)\n"
            let lineTokens = estimateTokens(convLine)

            if currentTokens + lineTokens > budget {
                break
            }

            result += convLine
            currentTokens += lineTokens
        }

        return result
    }

    private func buildCurrentMessages(messages: [MessageItem], budget: Int) -> String {
        guard !messages.isEmpty else {
            return "[Current Conversation]\n(No messages yet)"
        }

        let result = "[Current Conversation]\n"
        let headerTokens = estimateTokens(result)

        // Build messages from most recent, working backwards
        var messageLines: [String] = []
        var currentTokens = headerTokens

        for message in messages.reversed() {
            let sender = message.fromUser ? "User" : "Assistant"
            let line = "\(sender): \(message.text)\n"
            let lineTokens = estimateTokens(line)

            if currentTokens + lineTokens > budget {
                break
            }

            messageLines.insert(line, at: 0)
            currentTokens += lineTokens
        }

        return result + messageLines.joined()
    }

    // MARK: - Token Estimation

    /// Rough token estimation (~4 characters per token for English)
    private func estimateTokens(_ text: String) -> Int {
        return max(1, text.count / 4)
    }
}
