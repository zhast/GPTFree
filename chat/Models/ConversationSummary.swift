//
//  ConversationSummary.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import Foundation

struct ConversationSummary: Codable {
    var generatedTitle: String
    var summaryText: String
    var keyTopics: [String]
    var userMessageSnippets: [String]
    var participants: [String]
    var messageCount: Int
    var chunkSummaries: [String]?
    let generatedAt: Date

    init(
        generatedTitle: String,
        summaryText: String,
        keyTopics: [String] = [],
        userMessageSnippets: [String] = [],
        participants: [String] = ["User", "Assistant"],
        messageCount: Int = 0,
        chunkSummaries: [String]? = nil,
        generatedAt: Date = Date()
    ) {
        self.generatedTitle = generatedTitle
        self.summaryText = summaryText
        self.keyTopics = keyTopics
        self.userMessageSnippets = userMessageSnippets
        self.participants = participants
        self.messageCount = messageCount
        self.chunkSummaries = chunkSummaries
        self.generatedAt = generatedAt
    }
}
