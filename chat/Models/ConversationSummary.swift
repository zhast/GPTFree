//
//  ConversationSummary.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import Foundation

struct ConversationSummary: Codable, Sendable {
    var generatedTitle: String
    var summaryText: String
    var keyTopics: [String]
    var userMessageSnippets: [String]
    var participants: [String]
    var messageCount: Int
    var chunkSummaries: [String]?
    var originalTokenCount: Int
    let generatedAt: Date

    /// Tokens used by this summary when sent to LLM (title + summary text)
    var summaryTokenCount: Int {
        (generatedTitle.count + summaryText.count) / 4
    }

    /// Compression ratio as percentage (0-100)
    var compressionPercentage: Int {
        guard originalTokenCount > 0 else { return 0 }
        return Int((1.0 - Double(summaryTokenCount) / Double(originalTokenCount)) * 100)
    }

    nonisolated init(
        generatedTitle: String,
        summaryText: String,
        keyTopics: [String] = [],
        userMessageSnippets: [String] = [],
        participants: [String] = ["User", "Assistant"],
        messageCount: Int = 0,
        chunkSummaries: [String]? = nil,
        originalTokenCount: Int = 0,
        generatedAt: Date = Date()
    ) {
        self.generatedTitle = generatedTitle
        self.summaryText = summaryText
        self.keyTopics = keyTopics
        self.userMessageSnippets = userMessageSnippets
        self.participants = participants
        self.messageCount = messageCount
        self.chunkSummaries = chunkSummaries
        self.originalTokenCount = originalTokenCount
        self.generatedAt = generatedAt
    }
}
