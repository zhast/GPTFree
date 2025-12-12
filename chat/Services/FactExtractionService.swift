//
//  FactExtractionService.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import Foundation
import FoundationModels

// Structured output for fact extraction
@Generable
struct ExtractedFact {
    @Guide(description: "True ONLY if the message contains a lasting personal fact about the user (name, job, hobby, preference, goal, location). False for opinions about the conversation, reactions, questions, or temporary states.")
    let hasFact: Bool

    @Guide(description: "The fact summarized in third person, starting with a verb. Examples: 'Likes pizza', 'Wants a Porsche', 'Works as a developer', 'Lives in Seattle'. Keep under 8 words. Empty if no fact.")
    let fact: String
}

actor FactExtractionService {
    static let shared = FactExtractionService()

    private init() {}

    /// Extracts user facts from a single user message (lightweight, for real-time extraction)
    func extractFactsFromMessage(_ userMessage: String, conversationId: UUID) async throws -> [UserFact] {
        guard !userMessage.isEmpty else { return [] }

        // Skip questions - they don't contain facts about the user
        let trimmed = userMessage.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("?") || trimmed.lowercased().hasPrefix("what") ||
           trimmed.lowercased().hasPrefix("how") || trimmed.lowercased().hasPrefix("why") ||
           trimmed.lowercased().hasPrefix("when") || trimmed.lowercased().hasPrefix("where") ||
           trimmed.lowercased().hasPrefix("can you") || trimmed.lowercased().hasPrefix("could you") {
            #if DEBUG
            print("[FactExtraction] Skipping question: \(userMessage)")
            #endif
            return []
        }

        let instructions = """
            Extract personal facts when users share information about themselves.
            """

        let prompt = """
            Message: "\(userMessage)"

            If this contains a personal fact (like, dislike, preference, job, name, hobby), set hasFact=true and extract it.
            Examples that SHOULD be extracted: "I like pizza", "I'm a teacher", "I love hiking", "My name is John", "I like hot tubs"
            Examples that should NOT be extracted: "That's interesting", "Thanks", "OK"
            """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt, generating: ExtractedFact.self)

        #if DEBUG
        print("[FactExtraction] Input: \(userMessage)")
        print("[FactExtraction] Response: hasFact=\(response.content.hasFact), fact=\(response.content.fact)")
        #endif

        guard response.content.hasFact && !response.content.fact.isEmpty else {
            #if DEBUG
            print("[FactExtraction] No fact found")
            #endif
            return []
        }

        let userFact = UserFact(
            category: .context,
            content: response.content.fact,
            confidence: 0.8,
            source: .autoExtracted(conversationId: conversationId),
            isUserVerified: false
        )

        #if DEBUG
        print("[FactExtraction] Extracted: \(userFact.content)")
        #endif
        return [userFact]
    }

    /// Checks if a fact is similar to any existing facts
    func isDuplicate(_ newFact: String, existingFacts: [UserFact]) -> Bool {
        let newLower = newFact.lowercased()
        let newWords = Set(newLower.split(separator: " ").map(String.init))

        for existing in existingFacts {
            let existingLower = existing.content.lowercased()

            // Exact match
            if newLower == existingLower {
                #if DEBUG
                print("[FactExtraction] Duplicate: exact match with '\(existing.content)'")
                #endif
                return true
            }

            // One contains the other
            if newLower.contains(existingLower) || existingLower.contains(newLower) {
                #if DEBUG
                print("[FactExtraction] Duplicate: '\(newFact)' overlaps with '\(existing.content)'")
                #endif
                return true
            }

            // Significant word overlap (>70% of words match)
            let existingWords = Set(existingLower.split(separator: " ").map(String.init))
            let minWordCount = min(newWords.count, existingWords.count)

            // Skip overlap check if either set is too small
            guard minWordCount >= 2 else { continue }

            let commonWords = newWords.intersection(existingWords)
            let overlapRatio = Double(commonWords.count) / Double(minWordCount)

            if overlapRatio > 0.7 {
                #if DEBUG
                print("[FactExtraction] Duplicate: high word overlap (\(Int(overlapRatio * 100))%) with '\(existing.content)'")
                #endif
                return true
            }
        }

        return false
    }

    /// Extracts user facts from a full conversation (for batch processing)
    func extractFacts(from messages: [MessageItem], conversationId: UUID) async throws -> [UserFact] {
        // Only extract from user messages
        let userMessages = messages.filter { $0.fromUser }
        guard !userMessages.isEmpty else { return [] }

        // Build conversation text for analysis
        let conversationText = messages.map { message in
            let sender = message.fromUser ? "User" : "Assistant"
            return "\(sender): \(message.text)"
        }.joined(separator: "\n")

        let instructions = """
            You are a fact extraction system. Analyze conversations and extract factual information about the user.
            Only extract explicit facts that the user has directly stated. Do not make assumptions.
            """

        let prompt = """
            Analyze the following conversation and extract factual information about the user.

            Categories to look for:
            - personalInfo: Name, age, location, occupation, relationships
            - preferences: Likes, dislikes, preferred styles or approaches
            - goals: What the user wants to achieve or learn
            - context: Background information, current projects, hobbies
            - instructions: How the user wants you to behave or respond

            Conversation:
            \(conversationText)

            For each fact found, respond with one fact per line in this exact format:
            CATEGORY|CONTENT|CONFIDENCE

            Where:
            - CATEGORY is one of: personalInfo, preferences, goals, context, instructions
            - CONTENT is the fact itself (keep it concise)
            - CONFIDENCE is a number between 0.5 and 1.0

            Only include facts you are confident about. If no facts are found, respond with "NO_FACTS".
            """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)

        return parseFactsResponse(response.content, conversationId: conversationId)
    }

    private func parseFactsResponse(_ response: String, conversationId: UUID) -> [UserFact] {
        let lines = response.split(separator: "\n")
        var facts: [UserFact] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "NO_FACTS" || trimmed.isEmpty {
                continue
            }

            let parts = trimmed.split(separator: "|")
            guard parts.count == 3 else { continue }

            let categoryStr = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let content = String(parts[1]).trimmingCharacters(in: .whitespaces)
            let confidenceStr = String(parts[2]).trimmingCharacters(in: .whitespaces)

            guard let category = parseCategory(categoryStr),
                  let confidence = Double(confidenceStr),
                  !content.isEmpty else {
                continue
            }

            let fact = UserFact(
                category: category,
                content: content,
                confidence: min(max(confidence, 0.5), 1.0),
                source: .autoExtracted(conversationId: conversationId),
                isUserVerified: false
            )
            facts.append(fact)
        }

        return facts
    }

    private func parseCategory(_ str: String) -> UserFact.FactCategory? {
        switch str.lowercased() {
        case "personalinfo": return .personalInfo
        case "preferences": return .preferences
        case "goals": return .goals
        case "context": return .context
        case "instructions": return .instructions
        default: return nil
        }
    }
}
