//
//  SummaryGenerationService.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import Foundation
import FoundationModels

// MARK: - Structured Output Types

@Generable
struct ChunkSummary {
    @Guide(description: "What was the user trying to figure out, and what did they learn or decide? Focus on intent and outcome, not facts discussed.")
    let summary: String

    @Guide(description: "3-5 key topics, comma-separated")
    let topics: String

    @Guide(description: "Participant names, comma-separated")
    let participants: String
}

@Generable
struct SinglePassSummary {
    @Guide(description: "Title capturing user's goal, 3-5 words. Example: 'Learning SwiftUI Basics' or 'Evaluating Hot Tub Purchase'")
    let title: String

    @Guide(description: "What the user wanted to figure out, what they learned or decided, and any preferences revealed. Focus on the user's journey, not facts.")
    let summary: String

    @Guide(description: "3-5 key topics, comma-separated")
    let topics: String

    @Guide(description: "Participant names, comma-separated")
    let participants: String
}

@Generable
struct FinalMergedSummary {
    @Guide(description: "Title capturing user's goal, 3-5 words")
    let title: String

    @Guide(description: "What the user was trying to accomplish, what they learned or decided, and any perspective shifts. This helps personalize future responses.")
    let summary: String

    @Guide(description: "4-6 key topics, comma-separated")
    let topics: String
}

// MARK: - Summary Generation Service

actor SummaryGenerationService {
    static let shared = SummaryGenerationService()

    private let chunkSize = 20
    private let maxChunks = 10

    private init() {}

    // MARK: - Public API

    /// Generates a summary for a conversation using chunked summarization for long chats
    func generateSummary(from messages: [MessageItem]) async throws -> ConversationSummary {
        guard !messages.isEmpty else {
            return emptySummary()
        }

        #if DEBUG
        print("[Summary] Generating summary for \(messages.count) messages")
        #endif

        // Short chat: single pass (no chunking needed)
        if messages.count <= chunkSize {
            #if DEBUG
            print("[Summary] Using single-pass summarization")
            #endif
            return try await summarizeSinglePass(messages)
        }

        // Long chat: chunked approach
        #if DEBUG
        print("[Summary] Using chunked summarization")
        #endif
        return try await summarizeWithChunks(messages)
    }

    /// Generates just a title from the first message (faster, no LLM call)
    func generateQuickTitle(from firstMessage: String) -> String {
        let words = firstMessage.split(separator: " ").prefix(5)
        let title = words.joined(separator: " ")
        return title + (firstMessage.split(separator: " ").count > 5 ? "..." : "")
    }

    // MARK: - Single Pass (Short Conversations)

    private func summarizeSinglePass(_ messages: [MessageItem]) async throws -> ConversationSummary {
        let formatted = formatMessages(messages)
        let snippets = extractSnippets(from: messages)

        let instructions = """
            You summarize chats to help personalize future responses. Focus on understanding the user, not recapping facts.
            """

        let prompt = """
            Summarize this chat for context in future conversations:
            1. What was the user trying to figure out or decide?
            2. What did they learn, conclude, or choose?
            3. What preferences or perspectives did this reveal about them?

            \(formatted)
            """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt, generating: SinglePassSummary.self)
        let result = response.content

        // Calculate original token count
        let originalTokens = estimateTokens(formatted)

        return ConversationSummary(
            generatedTitle: result.title,
            summaryText: result.summary,
            keyTopics: deduplicateTopics(parseCommaSeparated(result.topics)),
            userMessageSnippets: snippets,
            participants: parseCommaSeparated(result.participants),
            messageCount: messages.count,
            chunkSummaries: nil,
            originalTokenCount: originalTokens
        )
    }

    // MARK: - Chunked Summarization (Long Conversations)

    private func summarizeWithChunks(_ messages: [MessageItem]) async throws -> ConversationSummary {
        // 1. Split into chunks
        let chunks = splitIntoChunks(messages)

        #if DEBUG
        print("[Summary] Split into \(chunks.count) chunks")
        #endif

        // 2. Summarize each chunk
        var chunkResults: [ChunkSummary] = []
        var allParticipants: Set<String> = []

        for (index, chunk) in chunks.enumerated() {
            #if DEBUG
            print("[Summary] Summarizing chunk \(index + 1)/\(chunks.count) (\(chunk.count) messages)")
            #endif

            let result = try await summarizeChunk(chunk, chunkNumber: index + 1, totalChunks: chunks.count)
            chunkResults.append(result)
            allParticipants.formUnion(parseCommaSeparated(result.participants))
        }

        // 3. Merge chunk summaries into final
        #if DEBUG
        print("[Summary] Merging \(chunkResults.count) chunk summaries")
        #endif

        let finalResult = try await mergeChunkSummaries(chunkResults)

        // Deduplicate topics from final result
        let dedupedTopics = deduplicateTopics(parseCommaSeparated(finalResult.topics))

        // Calculate original token count
        let originalTokens = estimateTokens(formatMessages(messages))

        return ConversationSummary(
            generatedTitle: finalResult.title,
            summaryText: finalResult.summary,
            keyTopics: dedupedTopics,
            userMessageSnippets: extractSnippets(from: messages),
            participants: Array(allParticipants),
            messageCount: messages.count,
            chunkSummaries: chunkResults.map { $0.summary },
            originalTokenCount: originalTokens
        )
    }

    private func summarizeChunk(_ messages: [MessageItem], chunkNumber: Int, totalChunks: Int) async throws -> ChunkSummary {
        let formatted = formatMessages(messages)

        let instructions = """
            Summarize to understand the user better, not to recap facts.
            """

        let prompt = """
            For this conversation segment (part \(chunkNumber) of \(totalChunks)):
            What was the user trying to figure out? What did they learn or decide?

            \(formatted)
            """

        let session = LanguageModelSession(instructions: instructions)
        return try await session.respond(to: prompt, generating: ChunkSummary.self).content
    }

    private func mergeChunkSummaries(_ chunks: [ChunkSummary]) async throws -> FinalMergedSummary {
        let combinedText = chunks.enumerated().map { index, chunk in
            "Part \(index + 1): \(chunk.summary)"
        }.joined(separator: "\n")

        let instructions = """
            Create a summary that helps personalize future conversations with this user.
            """

        let prompt = """
            Combine these into one summary that captures:
            - What the user was trying to accomplish overall
            - Key decisions or perspective shifts they made
            - What this reveals about their preferences

            \(combinedText)
            """

        let session = LanguageModelSession(instructions: instructions)
        return try await session.respond(to: prompt, generating: FinalMergedSummary.self).content
    }

    // MARK: - Helper Functions

    private func emptySummary() -> ConversationSummary {
        ConversationSummary(
            generatedTitle: "Empty Chat",
            summaryText: "No messages yet.",
            keyTopics: [],
            userMessageSnippets: [],
            participants: [],
            messageCount: 0,
            chunkSummaries: nil,
            originalTokenCount: 0
        )
    }

    private func estimateTokens(_ text: String) -> Int {
        // Rough estimate: ~4 characters per token
        text.count / 4
    }

    private func splitIntoChunks(_ messages: [MessageItem]) -> [[MessageItem]] {
        stride(from: 0, to: messages.count, by: chunkSize)
            .prefix(maxChunks)
            .map { startIndex in
                Array(messages[startIndex..<min(startIndex + chunkSize, messages.count)])
            }
    }

    private func formatMessages(_ messages: [MessageItem]) -> String {
        messages.map { msg in
            let sender = msg.fromUser ? "User" : "Assistant"
            return "\(sender): \(msg.text)"
        }.joined(separator: "\n")
    }

    private func extractSnippets(from messages: [MessageItem]) -> [String] {
        let userMessages = messages.filter { $0.fromUser }
        return userMessages.prefix(3).map { message in
            let words = message.text.split(separator: " ").prefix(10)
            return words.joined(separator: " ") + (message.text.split(separator: " ").count > 10 ? "..." : "")
        }
    }

    private func parseCommaSeparated(_ str: String) -> [String] {
        str.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Removes redundant topics where one contains another
    private func deduplicateTopics(_ topics: [String]) -> [String] {
        let lowercased = topics.map { ($0, $0.lowercased()) }

        return lowercased.compactMap { (original, lower) -> String? in
            // Keep this topic only if no OTHER topic contains it as a substring
            let dominated = lowercased.contains { (otherOriginal, otherLower) in
                otherOriginal != original &&
                otherLower.contains(lower) &&
                otherLower.count > lower.count
            }

            // Also check if this topic contains another (keep the more specific one)
            let dominates = lowercased.contains { (otherOriginal, otherLower) in
                otherOriginal != original &&
                lower.contains(otherLower) &&
                lower.count > otherLower.count
            }

            // Keep if: not dominated by another, OR if it dominates others (it's more specific)
            if dominated && !dominates {
                return nil
            }
            return original
        }
    }
}
