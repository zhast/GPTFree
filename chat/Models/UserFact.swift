//
//  UserFact.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import Foundation

struct UserFact: Identifiable, Codable, Sendable {
    let id: UUID
    var category: FactCategory
    var content: String
    var confidence: Double
    var source: FactSource
    let createdAt: Date
    var updatedAt: Date
    var isUserVerified: Bool

    nonisolated init(id: UUID = UUID(), category: FactCategory, content: String, confidence: Double = 0.8, source: FactSource = .userCreated, createdAt: Date = Date(), updatedAt: Date = Date(), isUserVerified: Bool = false) {
        self.id = id
        self.category = category
        self.content = content
        self.confidence = confidence
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isUserVerified = isUserVerified
    }

    enum FactCategory: String, Codable, CaseIterable {
        case personalInfo = "Personal Info"
        case preferences = "Preferences"
        case goals = "Goals"
        case context = "Context"
        case instructions = "Instructions"
    }

    enum FactSource: Codable, Equatable {
        case autoExtracted(conversationId: UUID)
        case userCreated
        case userEdited
    }
}
