#!/usr/bin/env swift
//
//  SummarizationTests.swift
//  Standalone test script for chat summarization logic
//
//  Run with: swift SummarizationTests.swift
//

import Foundation

// MARK: - Test Framework

var passedTests = 0
var failedTests = 0
var currentSection = ""

func section(_ name: String) {
    currentSection = name
    print("\n\u{001B}[1m=== \(name) ===\u{001B}[0m")
}

func test(_ name: String, _ condition: Bool, file: String = #file, line: Int = #line) {
    if condition {
        print("  \u{001B}[32m✓\u{001B}[0m \(name)")
        passedTests += 1
    } else {
        print("  \u{001B}[31m✗\u{001B}[0m \(name) (line \(line))")
        failedTests += 1
    }
}

func assertEqual<T: Equatable>(_ name: String, _ actual: T, _ expected: T) {
    if actual == expected {
        print("  \u{001B}[32m✓\u{001B}[0m \(name)")
        passedTests += 1
    } else {
        print("  \u{001B}[31m✗\u{001B}[0m \(name)")
        print("      Expected: \(expected)")
        print("      Actual:   \(actual)")
        failedTests += 1
    }
}

// MARK: - Mock Types (matching app's data models)

struct MockMessage {
    let id: UUID
    let conversationId: UUID
    let text: String
    let fromUser: Bool
    let timestamp: Date
    var senderName: String? // For multi-participant support

    init(text: String, fromUser: Bool, senderName: String? = nil) {
        self.id = UUID()
        self.conversationId = UUID()
        self.text = text
        self.fromUser = fromUser
        self.timestamp = Date()
        self.senderName = senderName
    }
}

struct MockConversationSummary {
    var generatedTitle: String
    var summaryText: String
    var keyTopics: [String]
    var userMessageSnippets: [String]
    var participants: [String]
    var messageCount: Int
    var chunkSummaries: [String]?
}

// MARK: - Helper Functions (copied from SummaryGenerationService)

func splitIntoChunks(_ messages: [MockMessage], chunkSize: Int = 20, maxChunks: Int = 10) -> [[MockMessage]] {
    stride(from: 0, to: messages.count, by: chunkSize)
        .prefix(maxChunks)
        .map { startIndex in
            Array(messages[startIndex..<min(startIndex + chunkSize, messages.count)])
        }
}

func formatMessages(_ messages: [MockMessage]) -> String {
    messages.map { msg in
        let sender = msg.senderName ?? (msg.fromUser ? "User" : "Assistant")
        return "[\(sender)]: \(msg.text)"
    }.joined(separator: "\n")
}

func extractSnippets(from messages: [MockMessage], limit: Int = 3, wordLimit: Int = 10) -> [String] {
    let userMessages = messages.filter { $0.fromUser }
    return userMessages.prefix(limit).map { message in
        let words = message.text.split(separator: " ").prefix(wordLimit)
        return words.joined(separator: " ") + (message.text.split(separator: " ").count > wordLimit ? "..." : "")
    }
}

func parseCommaSeparated(_ str: String) -> [String] {
    str.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
}

func generateTitleFromTopics(_ topics: String) -> String {
    let parsed = parseCommaSeparated(topics)
    if parsed.isEmpty {
        return "Chat"
    }
    return parsed.prefix(3).joined(separator: " & ")
}

// MARK: - Test Data Generators

func generateShortConversation() -> [MockMessage] {
    [
        MockMessage(text: "Hi there! I need help with SwiftUI.", fromUser: true),
        MockMessage(text: "Hello! I'd be happy to help with SwiftUI. What would you like to know?", fromUser: false),
        MockMessage(text: "How do I create a list view?", fromUser: true),
        MockMessage(text: "You can use the List view in SwiftUI. Here's an example...", fromUser: false),
        MockMessage(text: "Thanks, that's really helpful!", fromUser: true),
        MockMessage(text: "You're welcome! Let me know if you have more questions.", fromUser: false)
    ]
}

func generateLongConversation(messageCount: Int) -> [MockMessage] {
    (0..<messageCount).map { i in
        let topics = ["SwiftUI", "UIKit", "Combine", "async/await", "CoreData"]
        let topic = topics[i % topics.count]
        let isUser = i % 2 == 0
        let text = isUser
            ? "Question \(i + 1): Can you explain \(topic) in more detail?"
            : "Sure! \(topic) is a powerful framework. Here's what you need to know about it..."
        return MockMessage(text: text, fromUser: isUser)
    }
}

func generateMultiParticipantChat() -> [MockMessage] {
    [
        MockMessage(text: "Hey team, let's discuss the project timeline.", fromUser: true, senderName: "Alice"),
        MockMessage(text: "Good idea! I think we need 2 more weeks for testing.", fromUser: true, senderName: "Bob"),
        MockMessage(text: "That sounds reasonable. What about the design phase?", fromUser: true, senderName: "Carol"),
        MockMessage(text: "Design is almost done, maybe 3-4 days left.", fromUser: true, senderName: "Alice"),
        MockMessage(text: "Perfect. I can start backend work tomorrow then.", fromUser: true, senderName: "Bob"),
        MockMessage(text: "Let's sync up on Friday to review progress.", fromUser: true, senderName: "Carol"),
        MockMessage(text: "Friday works for me!", fromUser: true, senderName: "Alice"),
        MockMessage(text: "Same here. See you all then!", fromUser: true, senderName: "Bob")
    ]
}

func generateConversationWithSpecialCharacters() -> [MockMessage] {
    [
        MockMessage(text: "I love coding! 🚀 It's really \"awesome\"", fromUser: true),
        MockMessage(text: "That's great! 😊 What languages do you use?", fromUser: false),
        MockMessage(text: "Swift, Python, and JavaScript — my favorites!", fromUser: true),
        MockMessage(text: "Nice choices! Here's a tip: use `guard` statements in Swift", fromUser: false),
        MockMessage(text: "Thanks! I'll remember that 👍", fromUser: true)
    ]
}

func generateConversationWithLongMessages() -> [MockMessage] {
    let longText = String(repeating: "This is a very long message that goes on and on. ", count: 20)
    return [
        MockMessage(text: longText, fromUser: true),
        MockMessage(text: "I understand. Let me summarize that for you.", fromUser: false),
        MockMessage(text: "Yes please, that would be helpful!", fromUser: true)
    ]
}

// MARK: - Tests

print("\n\u{001B}[1;36m╔════════════════════════════════════════════════╗\u{001B}[0m")
print("\u{001B}[1;36m║     CHAT SUMMARIZATION TEST SUITE              ║\u{001B}[0m")
print("\u{001B}[1;36m╚════════════════════════════════════════════════╝\u{001B}[0m")

// MARK: Test 1: Chunking Logic

section("Chunking Logic")

do {
    let messages = generateLongConversation(messageCount: 50)
    let chunks = splitIntoChunks(messages)

    assertEqual("50 messages splits into 3 chunks", chunks.count, 3)
    assertEqual("First chunk has 20 messages", chunks[0].count, 20)
    assertEqual("Second chunk has 20 messages", chunks[1].count, 20)
    assertEqual("Third chunk has 10 messages", chunks[2].count, 10)
}

do {
    let messages = generateLongConversation(messageCount: 250)
    let chunks = splitIntoChunks(messages, maxChunks: 10)

    assertEqual("250 messages capped at 10 chunks", chunks.count, 10)
    test("Max chunks limits total messages to 200", chunks.flatMap { $0 }.count == 200)
}

do {
    let messages = generateShortConversation()
    let chunks = splitIntoChunks(messages)

    assertEqual("6 messages stays in 1 chunk", chunks.count, 1)
    assertEqual("Single chunk contains all messages", chunks[0].count, 6)
}

do {
    let empty: [MockMessage] = []
    let chunks = splitIntoChunks(empty)

    assertEqual("Empty array produces 0 chunks", chunks.count, 0)
}

do {
    let single = [MockMessage(text: "Hello", fromUser: true)]
    let chunks = splitIntoChunks(single)

    assertEqual("Single message produces 1 chunk", chunks.count, 1)
    assertEqual("Single chunk has 1 message", chunks[0].count, 1)
}

// MARK: Test 2: Message Formatting

section("Message Formatting")

do {
    let messages = generateShortConversation()
    let formatted = formatMessages(messages)

    test("Contains [User]: prefix", formatted.contains("[User]:"))
    test("Contains [Assistant]: prefix", formatted.contains("[Assistant]:"))
    test("First line is from user", formatted.hasPrefix("[User]:"))
}

do {
    let messages = generateMultiParticipantChat()
    let formatted = formatMessages(messages)

    test("Multi-participant shows Alice", formatted.contains("[Alice]:"))
    test("Multi-participant shows Bob", formatted.contains("[Bob]:"))
    test("Multi-participant shows Carol", formatted.contains("[Carol]:"))
    test("Does not use generic User/Assistant", !formatted.contains("[User]:") && !formatted.contains("[Assistant]:"))
}

do {
    let messages = generateConversationWithSpecialCharacters()
    let formatted = formatMessages(messages)

    test("Preserves emoji 🚀", formatted.contains("🚀"))
    test("Preserves quotes", formatted.contains("\"awesome\""))
    test("Preserves emoji 😊", formatted.contains("😊"))
    test("Preserves backticks", formatted.contains("`guard`"))
}

// MARK: Test 3: Snippet Extraction

section("Snippet Extraction")

do {
    let messages = generateShortConversation()
    let snippets = extractSnippets(from: messages)

    assertEqual("Extracts up to 3 snippets", snippets.count, 3)
    test("First snippet is from first user message", snippets[0].contains("Hi there"))
    test("Only user messages in snippets", snippets.allSatisfy { !$0.contains("Hello! I'd be happy") })
}

do {
    let messages = generateConversationWithLongMessages()
    let snippets = extractSnippets(from: messages)

    test("Long messages get truncated", snippets[0].hasSuffix("..."))
    test("Truncated snippet has ~10 words", snippets[0].split(separator: " ").count <= 11)
}

do {
    let assistantOnly = [
        MockMessage(text: "Hello!", fromUser: false),
        MockMessage(text: "How can I help?", fromUser: false)
    ]
    let snippets = extractSnippets(from: assistantOnly)

    assertEqual("No user messages = no snippets", snippets.count, 0)
}

// MARK: Test 4: Comma-Separated Parsing

section("Comma-Separated Parsing")

do {
    let result = parseCommaSeparated("SwiftUI, Navigation, State Management")

    assertEqual("Parses 3 topics", result.count, 3)
    assertEqual("First topic trimmed", result[0], "SwiftUI")
    assertEqual("Last topic trimmed", result[2], "State Management")
}

do {
    let result = parseCommaSeparated("  spaced  ,  values  ,  here  ")

    test("Trims whitespace from all values", result.allSatisfy { !$0.hasPrefix(" ") && !$0.hasSuffix(" ") })
}

do {
    let result = parseCommaSeparated("")
    assertEqual("Empty string = empty array", result.count, 0)
}

do {
    let result = parseCommaSeparated("single")
    assertEqual("Single value works", result.count, 1)
    assertEqual("Single value content", result[0], "single")
}

do {
    let result = parseCommaSeparated(",,,")
    assertEqual("Only commas = empty array", result.count, 0)
}

do {
    let result = parseCommaSeparated("one,,two")
    assertEqual("Skips empty segments", result.count, 2)
}

// MARK: Test 5: Title Generation

section("Title Generation from Topics")

do {
    let title = generateTitleFromTopics("SwiftUI, Navigation, State")
    assertEqual("Generates from first 3 topics", title, "SwiftUI & Navigation & State")
}

do {
    let title = generateTitleFromTopics("SingleTopic")
    assertEqual("Single topic title", title, "SingleTopic")
}

do {
    let title = generateTitleFromTopics("")
    assertEqual("Empty topics = 'Chat'", title, "Chat")
}

do {
    let title = generateTitleFromTopics("One, Two, Three, Four, Five")
    test("Limits to 3 topics", title.components(separatedBy: " & ").count == 3)
}

// MARK: Test 6: Multi-Participant Detection

section("Multi-Participant Chat Handling")

do {
    let messages = generateMultiParticipantChat()
    let senderNames = Set(messages.compactMap { $0.senderName })

    assertEqual("Identifies 3 participants", senderNames.count, 3)
    test("Contains Alice", senderNames.contains("Alice"))
    test("Contains Bob", senderNames.contains("Bob"))
    test("Contains Carol", senderNames.contains("Carol"))
}

// MARK: Test 7: Edge Cases

section("Edge Cases")

do {
    // Exactly at chunk boundary
    let messages = generateLongConversation(messageCount: 20)
    let chunks = splitIntoChunks(messages)

    assertEqual("Exactly 20 messages = 1 chunk", chunks.count, 1)
    assertEqual("Chunk has all 20 messages", chunks[0].count, 20)
}

do {
    // Just over chunk boundary
    let messages = generateLongConversation(messageCount: 21)
    let chunks = splitIntoChunks(messages)

    assertEqual("21 messages = 2 chunks", chunks.count, 2)
    assertEqual("First chunk full", chunks[0].count, 20)
    assertEqual("Second chunk has 1", chunks[1].count, 1)
}

do {
    // Unicode handling
    let messages = [
        MockMessage(text: "你好世界! Hello World! مرحبا بالعالم", fromUser: true),
        MockMessage(text: "Multilingual support is important!", fromUser: false)
    ]
    let formatted = formatMessages(messages)

    test("Handles Chinese characters", formatted.contains("你好世界"))
    test("Handles Arabic characters", formatted.contains("مرحبا بالعالم"))
}

do {
    // Very long single message
    let veryLong = String(repeating: "word ", count: 1000)
    let messages = [MockMessage(text: veryLong, fromUser: true)]
    let snippets = extractSnippets(from: messages)

    test("Snippet truncates very long message", snippets[0].split(separator: " ").count <= 11)
}

// MARK: Test 8: Chunk Content Preservation

section("Chunk Content Preservation")

do {
    let messages = generateLongConversation(messageCount: 45)
    let chunks = splitIntoChunks(messages)

    // Verify all messages are preserved
    let totalMessages = chunks.flatMap { $0 }.count
    assertEqual("All 45 messages preserved in chunks", totalMessages, 45)

    // Verify order is maintained
    let firstMsgInChunk2 = chunks[1][0]
    test("Chunk 2 starts with message 21", firstMsgInChunk2.text.contains("Question 21"))
}

// MARK: - Results Summary

print("\n\u{001B}[1m" + String(repeating: "═", count: 50) + "\u{001B}[0m")
print("\u{001B}[1mRESULTS: \(passedTests) passed, \(failedTests) failed\u{001B}[0m")
print(String(repeating: "═", count: 50))

if failedTests == 0 {
    print("\n\u{001B}[32;1m✅ ALL TESTS PASSED!\u{001B}[0m\n")
    exit(0)
} else {
    print("\n\u{001B}[31;1m❌ SOME TESTS FAILED\u{001B}[0m\n")
    exit(1)
}
