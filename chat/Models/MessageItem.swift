//
//  MessageItem.swift
//  chat
//
//  Created by Steven Zhang on 11/13/25.
//

import Foundation

struct MessageItem: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    let conversationId: UUID
    let text: String
    let fromUser: Bool
    let timestamp: Date

    // Convenience initializer for creating messages in the current conversation
    nonisolated init(id: UUID = UUID(), conversationId: UUID, text: String, fromUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.fromUser = fromUser
        self.timestamp = timestamp
    }
}
