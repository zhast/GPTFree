//
//  MemoryStore.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import SwiftUI
import Combine

@MainActor
class MemoryStore: ObservableObject {
    @Published var facts: [UserFact] = []
    @Published var isExtracting: Bool = false

    private let persistence = PersistenceService.shared

    // MARK: - Loading

    func load() async {
        do {
            facts = try await persistence.loadFacts()
            // Sort by confidence (highest first), then by date
            facts.sort { ($0.isUserVerified ? 1 : 0, $0.confidence, $0.updatedAt) > ($1.isUserVerified ? 1 : 0, $1.confidence, $1.updatedAt) }
        } catch {
            print("Failed to load facts: \(error)")
        }
    }

    // MARK: - CRUD Operations

    func addFact(_ fact: UserFact) {
        facts.insert(fact, at: 0)
        save()
    }

    func updateFact(_ fact: UserFact) {
        if let index = facts.firstIndex(where: { $0.id == fact.id }) {
            var updatedFact = fact
            updatedFact.updatedAt = Date()
            updatedFact.source = .userEdited
            facts[index] = updatedFact
            save()
        }
    }

    func updateFact(_ id: UUID, content: String) {
        if let index = facts.firstIndex(where: { $0.id == id }) {
            facts[index].content = content
            facts[index].updatedAt = Date()
            facts[index].source = .userEdited
            save()
        }
    }

    func deleteFact(_ id: UUID) {
        facts.removeAll { $0.id == id }
        save()
    }

    func verifyFact(_ id: UUID) {
        if let index = facts.firstIndex(where: { $0.id == id }) {
            facts[index].isUserVerified = true
            facts[index].updatedAt = Date()
            save()
        }
    }

    // MARK: - Filtering

    func facts(by category: UserFact.FactCategory) -> [UserFact] {
        facts.filter { $0.category == category }
    }

    var verifiedFacts: [UserFact] {
        facts.filter { $0.isUserVerified }
    }

    var highConfidenceFacts: [UserFact] {
        facts.filter { $0.confidence >= 0.7 }
    }

    /// Facts suitable for inclusion in context (verified or high confidence)
    var factsForContext: [UserFact] {
        facts.filter { $0.isUserVerified || $0.confidence >= 0.6 }
    }

    // MARK: - Extraction Integration

    func addExtractedFacts(_ newFacts: [UserFact]) {
        for newFact in newFacts {
            // Check for duplicates by content similarity
            let isDuplicate = facts.contains { existing in
                existing.content.lowercased() == newFact.content.lowercased() &&
                existing.category == newFact.category
            }

            if !isDuplicate {
                facts.append(newFact)
            }
        }
        save()
    }

    // MARK: - Persistence

    private func save() {
        Task {
            do {
                try await persistence.saveFacts(facts)
            } catch {
                print("Failed to save facts: \(error)")
            }
        }
    }
}
