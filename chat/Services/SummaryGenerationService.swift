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
    @Guide(description: "One sentence: what was asked and resolved. Example: 'User asked about X, learned Y.'")
    let summary: String

    @Guide(description: "3-5 key topics, comma-separated. Pick specific terms only.")
    let topics: String

    @Guide(description: "Participant names, comma-separated")
    let participants: String
}

@Generable
struct SinglePassSummary {
    @Guide(description: "Title in 3-5 words. Example: 'SwiftUI Navigation Help'")
    let title: String

    @Guide(description: "One sentence: what user wanted and outcome. No fluff.")
    let summary: String

    @Guide(description: "3-5 key topics, comma-separated")
    let topics: String

    @Guide(description: "Participant names, comma-separated")
    let participants: String
}

@Generable
struct FinalMergedSummary {
    @Guide(description: "Title in 3-5 words. Example: 'Building a REST API'")
    let title: String

    @Guide(description: "1-2 sentences max. What user accomplished. No flowery language.")
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
            Summarize chats in minimal words. State facts only. Never use: "comprehensive", "guiding stars", "journey", "delved", "explored", "tackled".
            """

        let prompt = """
            Summarize this chat. What did the user want? What was the result?

            \(formatted)
            """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt, generating: SinglePassSummary.self)
        let result = response.content

        return ConversationSummary(
            generatedTitle: result.title,
            summaryText: result.summary,
            keyTopics: deduplicateTopics(parseCommaSeparated(result.topics)),
            userMessageSnippets: snippets,
            participants: parseCommaSeparated(result.participants),
            messageCount: messages.count,
            chunkSummaries: nil
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

        return ConversationSummary(
            generatedTitle: finalResult.title,
            summaryText: finalResult.summary,
            keyTopics: dedupedTopics,
            userMessageSnippets: extractSnippets(from: messages),
            participants: Array(allParticipants),
            messageCount: messages.count,
            chunkSummaries: chunkResults.map { $0.summary }
        )
    }

    private func summarizeChunk(_ messages: [MessageItem], chunkNumber: Int, totalChunks: Int) async throws -> ChunkSummary {
        let formatted = formatMessages(messages)

        let instructions = """
            Summarize in one sentence. Facts only. No flowery words.
            """

        let prompt = """
            Summarize this part of a conversation (part \(chunkNumber) of \(totalChunks)).

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
            Merge summaries into 1-2 sentences. Facts only. Never use flowery or academic language.
            """

        let prompt = """
            Combine these conversation parts into one summary. Create a short, memorable title.

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
            chunkSummaries: nil
        )
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
