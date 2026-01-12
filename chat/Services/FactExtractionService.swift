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

        let availability = AppleIntelligenceAvailability.effectiveAvailability(system: SystemLanguageModel.default.availability)
        guard case .available = availability else {
            #if DEBUG
            print("[FactExtraction] Skipping (model unavailable): \(availability)")
            #endif
            return []
        }

        let trimmed = userMessage.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()

        // Skip questions - they don't contain facts about the user
        if trimmed.hasSuffix("?") || lower.hasPrefix("what") ||
           lower.hasPrefix("how") || lower.hasPrefix("why") ||
           lower.hasPrefix("when") || lower.hasPrefix("where") ||
           lower.hasPrefix("can you") || lower.hasPrefix("could you") {
            #if DEBUG
            print("[FactExtraction] Skipping question: \(userMessage)")
            #endif
            return []
        }

        // Skip very short messages (single words, brief acknowledgments)
        if trimmed.count < 10 {
            #if DEBUG
            print("[FactExtraction] Skipping very short message: \(userMessage)")
            #endif
            return []
        }

        // Skip common conversational filler patterns
        let fillerPatterns = [
            "thanks", "thank you", "ok", "okay", "got it", "i see",
            "sounds good", "perfect", "great", "cool", "nice",
            "sure", "yes", "no", "right", "understood", "let me", "let's",
            "i understand", "alright", "i agree", "i'll do", "good point",
            "also,", "wait,", "actually,", "one more", "by the way"
        ]
        if fillerPatterns.contains(where: { lower.hasPrefix($0) }) && trimmed.count < 40 {
            #if DEBUG
            print("[FactExtraction] Skipping filler: \(userMessage)")
            #endif
            return []
        }

        // Skip commands/requests to the AI
        let commandPatterns = [
            "show me", "explain", "help me", "give me", "tell me",
            "can you show", "please explain", "please help"
        ]
        if commandPatterns.contains(where: { lower.hasPrefix($0) }) {
            #if DEBUG
            print("[FactExtraction] Skipping command: \(userMessage)")
            #endif
            return []
        }

        // Skip reactions about the conversation (usually start with "that's" or "that is")
        if (lower.hasPrefix("that's") || lower.hasPrefix("that is") || lower.hasPrefix("this is")) && trimmed.count < 30 {
            #if DEBUG
            print("[FactExtraction] Skipping reaction: \(userMessage)")
            #endif
            return []
        }

        // Skip temporary states (short messages only, to allow "I'm thinking about learning Rust")
        let shortTemporaryPatterns = [
            "i'm confused", "i'm stuck", "i'm lost",
            "i am confused", "i am stuck", "i am lost",
            "i don't understand", "i don't get", "i see what",
            "i'm a bit lost", "i'm still working", "i'm getting closer",
            "i'm having trouble", "oh wow"
        ]
        if shortTemporaryPatterns.contains(where: { lower.hasPrefix($0) }) && trimmed.count < 35 {
            #if DEBUG
            print("[FactExtraction] Skipping temporary state: \(userMessage)")
            #endif
            return []
        }

        // Skip emotional reactions about the current situation (any length)
        let emotionalPatterns = [
            "i'm excited to try", "i'm excited about", "i'm worried this",
            "i'm worried about", "i'm surprised", "i'm happy with this",
            "i'm frustrated with", "i'm not sure"
        ]
        if emotionalPatterns.contains(where: { lower.hasPrefix($0) }) {
            #if DEBUG
            print("[FactExtraction] Skipping emotional reaction: \(userMessage)")
            #endif
            return []
        }

        // Skip "makes sense" patterns
        if lower.contains("makes sense") || lower.contains("make sense") {
            #if DEBUG
            print("[FactExtraction] Skipping acknowledgment: \(userMessage)")
            #endif
            return []
        }

        // Skip hypotheticals (broader patterns)
        if lower.hasPrefix("if i were") || lower.hasPrefix("if i was") ||
           (lower.contains("i would") && lower.contains("if")) ||
           lower.hasPrefix("i would love to") || lower.hasPrefix("i would like to") ||
           lower.hasPrefix("i could see") || lower.hasPrefix("i might") {
            #if DEBUG
            print("[FactExtraction] Skipping hypothetical: \(userMessage)")
            #endif
            return []
        }

        // Skip quotes from others and hearsay
        if lower.contains("said '") || lower.contains("said \"") ||
           lower.contains("told me") || lower.hasPrefix("my friend") ||
           lower.hasPrefix("my coworker") || lower.hasPrefix("someone") ||
           lower.hasPrefix("i heard") {
            #if DEBUG
            print("[FactExtraction] Skipping quote/third-party: \(userMessage)")
            #endif
            return []
        }

        // Skip general statements not about the user
        if lower.hasPrefix("people") || lower.hasPrefix("everyone") ||
           lower.hasPrefix("most ") || lower.hasPrefix("usually") {
            #if DEBUG
            print("[FactExtraction] Skipping general statement: \(userMessage)")
            #endif
            return []
        }

        // Skip meta-conversation references
        let metaPatterns = [
            "going back to", "as i mentioned", "to clarify", "in other words",
            "as i said", "like i said", "what i meant"
        ]
        if metaPatterns.contains(where: { lower.hasPrefix($0) }) {
            #if DEBUG
            print("[FactExtraction] Skipping meta-conversation: \(userMessage)")
            #endif
            return []
        }

        // Skip opinions about external things (not user preferences)
        // These are statements about tech/products/code, not about the user
        if !lower.contains("i ") && !lower.contains("my ") && !lower.contains("i'm") &&
           (lower.contains(" is ") || lower.contains(" are ")) && trimmed.count < 40 {
            #if DEBUG
            print("[FactExtraction] Skipping external opinion: \(userMessage)")
            #endif
            return []
        }

        let instructions = """
            You extract LASTING personal facts about users. Be very selective.
            Only return hasFact=true for permanent traits, not temporary states or reactions.
            When uncertain, return hasFact=false.
            """

        let prompt = """
            Message: "\(userMessage)"

            Extract ONLY if this reveals a LASTING fact about the user such as:
            - Identity: name, age, location, nationality
            - Occupation: job, profession, employer
            - Preferences: likes, dislikes, favorites (NOT opinions about this conversation)
            - Life facts: family, pets, relationships, education
            - Goals: what they want to learn or achieve
            - Hobbies: activities they regularly do

            Set hasFact=false for:
            - Temporary states: "I'm confused", "I'm stuck", "I'm thinking"
            - Reactions to conversation: "That's helpful", "Makes sense", "Thanks"
            - Opinions about the chat: "Great explanation", "This is interesting"
            - Hypotheticals: "If I were...", "I would..."
            - Quotes from others: "My friend said..."
            - Generic statements not about the user

            Examples:
            "I'm a nurse" → hasFact=true, "Works as a nurse"
            "I love hiking" → hasFact=true, "Loves hiking"
            "I'm confused right now" → hasFact=false
            "Thanks for explaining" → hasFact=false
            "That's really helpful" → hasFact=false
            "My friend loves Python" → hasFact=false
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
