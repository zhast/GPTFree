//
//  Conversation.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import Foundation

struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var summary: ConversationSummary?
    var messageCount: Int

    init(id: UUID = UUID(), title: String = "New Chat", createdAt: Date = Date(), updatedAt: Date = Date(), summary: ConversationSummary? = nil, messageCount: Int = 0) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.summary = summary
        self.messageCount = messageCount
    }

    // Preview text for sidebar (first user message or title)
    var previewText: String {
        summary?.userMessageSnippets.first ?? title
    }
}
