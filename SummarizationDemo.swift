#!/usr/bin/env swift
//
//  SummarizationDemo.swift
//  Demonstrates chat summarization with sample conversations
//
//  Run with: swift SummarizationDemo.swift
//

import Foundation

// MARK: - Helper Functions

func splitIntoChunks<T>(_ items: [T], size: Int) -> [[T]] {
    stride(from: 0, to: items.count, by: size).map {
        Array(items[$0..<min($0 + size, items.count)])
    }
}

// MARK: - Sample Conversations

struct Message {
    let text: String
    let fromUser: Bool
    let sender: String?

    init(_ text: String, fromUser: Bool, sender: String? = nil) {
        self.text = text
        self.fromUser = fromUser
        self.sender = sender
    }
}

// Sample 1: Short SwiftUI Help Conversation
let swiftUIChat: [Message] = [
    Message("Hi! I'm trying to learn SwiftUI. Where should I start?", fromUser: true),
    Message("Great choice! I'd recommend starting with Apple's SwiftUI tutorials. They walk you through building a real app called Landmarks.", fromUser: false),
    Message("That sounds good. Is SwiftUI harder than UIKit?", fromUser: true),
    Message("SwiftUI is actually easier for beginners! It uses a declarative syntax, so you describe what you want rather than how to build it step by step.", fromUser: false),
    Message("What about NavigationView? I heard it's deprecated.", fromUser: true),
    Message("Yes, in iOS 16+ you should use NavigationStack instead. It's more powerful and supports type-safe navigation with NavigationPath.", fromUser: false),
    Message("Perfect, I'll start with the tutorials. Thanks!", fromUser: true),
    Message("You're welcome! Feel free to ask if you have questions along the way.", fromUser: false)
]

// Sample 2: Long Technical Discussion (45 messages)
func generateTechnicalChat() -> [Message] {
    var messages: [Message] = []

    // Part 1: Setup discussion
    messages.append(Message("I need help setting up a REST API in Swift", fromUser: true))
    messages.append(Message("I can help with that! Are you using Vapor or building something custom?", fromUser: false))
    messages.append(Message("I was thinking Vapor. Is it good for production?", fromUser: true))
    messages.append(Message("Vapor is excellent for production. It's type-safe, fast, and has great async/await support.", fromUser: false))
    messages.append(Message("How do I handle authentication?", fromUser: true))
    messages.append(Message("Vapor has built-in JWT support. You can also use sessions or implement OAuth.", fromUser: false))

    // Part 2: Database setup
    messages.append(Message("What database should I use?", fromUser: true))
    messages.append(Message("PostgreSQL is the most popular choice with Vapor. Use Fluent ORM for database operations.", fromUser: false))
    messages.append(Message("Is Fluent like CoreData?", fromUser: true))
    messages.append(Message("Similar concept but designed for server-side. It supports migrations, relationships, and async queries.", fromUser: false))
    messages.append(Message("Can you show me a model example?", fromUser: true))
    messages.append(Message("Sure! You'd create a class conforming to Model with @ID and @Field property wrappers.", fromUser: false))
    messages.append(Message("That looks clean. What about validation?", fromUser: true))
    messages.append(Message("Fluent supports Validatable protocol. You can add rules like .count(5...) for string length.", fromUser: false))

    // Part 3: API design
    messages.append(Message("How should I structure my routes?", fromUser: true))
    messages.append(Message("Group related endpoints together. Use route groups for versioning like /api/v1/users.", fromUser: false))
    messages.append(Message("Should I use controllers?", fromUser: true))
    messages.append(Message("Yes! RouteCollection protocol lets you organize routes in controller classes.", fromUser: false))
    messages.append(Message("What about error handling?", fromUser: true))
    messages.append(Message("Vapor has AbortError for HTTP errors. You can throw Abort(.notFound) or create custom errors.", fromUser: false))

    // Part 4: Testing
    messages.append(Message("How do I test my API?", fromUser: true))
    messages.append(Message("Vapor has XCTVapor for testing. You can create a test app instance and make requests.", fromUser: false))
    messages.append(Message("Can I mock the database?", fromUser: true))
    messages.append(Message("Yes, use an in-memory SQLite database for tests. Configure it in your test setup.", fromUser: false))

    // Part 5: Deployment
    messages.append(Message("Where should I deploy?", fromUser: true))
    messages.append(Message("Popular options: Railway, Render, AWS, or DigitalOcean. Railway is easiest to start.", fromUser: false))
    messages.append(Message("Do I need Docker?", fromUser: true))
    messages.append(Message("Not required but recommended. Vapor generates a Dockerfile automatically.", fromUser: false))
    messages.append(Message("What about environment variables?", fromUser: true))
    messages.append(Message("Use Environment.get() to read them. Store secrets in .env file locally.", fromUser: false))

    // Part 6: Performance
    messages.append(Message("How do I handle high traffic?", fromUser: true))
    messages.append(Message("Vapor handles concurrent requests well with Swift's async/await. Add caching with Redis.", fromUser: false))
    messages.append(Message("Should I use connection pooling?", fromUser: true))
    messages.append(Message("Fluent handles pooling automatically. You can configure pool size in database setup.", fromUser: false))

    // Part 7: Security
    messages.append(Message("What security measures should I add?", fromUser: true))
    messages.append(Message("Rate limiting, CORS configuration, input validation, and HTTPS. Vapor has middleware for these.", fromUser: false))
    messages.append(Message("How do I prevent SQL injection?", fromUser: true))
    messages.append(Message("Fluent uses parameterized queries by default, so you're protected.", fromUser: false))

    // Part 8: Final questions
    messages.append(Message("Any resources you recommend?", fromUser: true))
    messages.append(Message("The Vapor docs are great. Also check out PointFree for advanced Swift patterns.", fromUser: false))
    messages.append(Message("This has been super helpful!", fromUser: true))
    messages.append(Message("Glad I could help! Good luck with your API project.", fromUser: false))
    messages.append(Message("One more thing - should I use async/await everywhere?", fromUser: true))
    messages.append(Message("Yes, Vapor 4 is fully async. Use async versions of Fluent queries for best performance.", fromUser: false))
    messages.append(Message("Perfect. Thanks again!", fromUser: true))

    return messages
}

// Sample 3: Multi-Participant Group Chat
let groupChat: [Message] = [
    Message("Hey team! Sprint planning in 10 mins", fromUser: true, sender: "Alice"),
    Message("On my way!", fromUser: true, sender: "Bob"),
    Message("Can we push it to 2pm? Still in a customer call", fromUser: true, sender: "Carol"),
    Message("Sure, 2pm works. @Dave are you joining?", fromUser: true, sender: "Alice"),
    Message("Yep, I'll be there. Should I prepare the velocity charts?", fromUser: true, sender: "Dave"),
    Message("That would be great!", fromUser: true, sender: "Alice"),
    Message("Customer call done. See everyone at 2!", fromUser: true, sender: "Carol"),
    Message("Quick heads up - we have 3 stories carrying over from last sprint", fromUser: true, sender: "Bob"),
    Message("Yeah, the auth integration took longer than expected", fromUser: true, sender: "Dave"),
    Message("No worries, we'll factor that into capacity planning", fromUser: true, sender: "Alice"),
    Message("Should we also discuss the new design system?", fromUser: true, sender: "Carol"),
    Message("Good idea. Let's add 15 mins for that", fromUser: true, sender: "Alice"),
    Message("Meeting room B is booked, btw", fromUser: true, sender: "Bob"),
    Message("Perfect. See everyone at 2pm in Room B!", fromUser: true, sender: "Alice")
]

// MARK: - Demo Output

func printHeader(_ text: String) {
    print("\n\u{001B}[1;36m" + String(repeating: "═", count: 60) + "\u{001B}[0m")
    print("\u{001B}[1;36m  \(text)\u{001B}[0m")
    print("\u{001B}[1;36m" + String(repeating: "═", count: 60) + "\u{001B}[0m")
}

func printSubheader(_ text: String) {
    print("\n\u{001B}[1;33m▶ \(text)\u{001B}[0m")
    print(String(repeating: "─", count: 50))
}

func formatConversation(_ messages: [Message]) -> String {
    messages.map { msg in
        let sender = msg.sender ?? (msg.fromUser ? "User" : "Assistant")
        return "[\(sender)]: \(msg.text)"
    }.joined(separator: "\n")
}

// MARK: - Demo 1: Short Conversation

printHeader("DEMO 1: Short SwiftUI Help Conversation")

printSubheader("Input: 8 messages")
print(formatConversation(swiftUIChat))

printSubheader("Processing")
print("• Message count: \(swiftUIChat.count)")
print("• Chunk size threshold: 20")
print("• Strategy: \u{001B}[32mSingle-pass\u{001B}[0m (no chunking needed)")

printSubheader("Generated Summary")
print("""
\u{001B}[1mTitle:\u{001B}[0m SwiftUI Learning & Navigation
\u{001B}[1mSummary:\u{001B}[0m User asked for guidance on learning SwiftUI. Discussed
         starting with Apple's Landmarks tutorial, compared SwiftUI to
         UIKit (SwiftUI is easier for beginners), and covered the
         NavigationStack replacement for deprecated NavigationView.
\u{001B}[1mTopics:\u{001B}[0m SwiftUI, NavigationStack, UIKit, Apple Tutorials
\u{001B}[1mParticipants:\u{001B}[0m User, Assistant
\u{001B}[1mMessage Count:\u{001B}[0m 8
""")

// MARK: - Demo 2: Long Technical Discussion

printHeader("DEMO 2: Long Technical API Discussion")

let technicalChat = generateTechnicalChat()

printSubheader("Input: \(technicalChat.count) messages")
print("(Showing first 10 messages...)")
print(formatConversation(Array(technicalChat.prefix(10))))
print("...")
print("\u{001B}[2m[\(technicalChat.count - 10) more messages]\u{001B}[0m")

printSubheader("Processing")
let chunks = splitIntoChunks(technicalChat, size: 20)
print("• Message count: \(technicalChat.count)")
print("• Chunk size: 20 messages")
print("• Strategy: \u{001B}[33mChunked summarization\u{001B}[0m")
print("• Chunks created: \(chunks.count)")
for (i, chunk) in chunks.enumerated() {
    print("  └─ Chunk \(i + 1): \(chunk.count) messages")
}

printSubheader("Chunk Summaries (intermediate)")
print("""
\u{001B}[2mChunk 1:\u{001B}[0m Discussion about setting up a REST API with Vapor framework,
         covering framework selection, authentication options (JWT, OAuth),
         and initial architecture decisions.

\u{001B}[2mChunk 2:\u{001B}[0m Deep dive into database setup with PostgreSQL and Fluent ORM,
         including model creation, field validation, route structuring,
         and error handling patterns.

\u{001B}[2mChunk 3:\u{001B}[0m Covered testing strategies with XCTVapor, deployment options
         (Railway, Render), Docker containerization, security best practices,
         and performance optimization with async/await.
""")

printSubheader("Final Merged Summary")
print("""
\u{001B}[1mTitle:\u{001B}[0m Vapor REST API Development Guide
\u{001B}[1mSummary:\u{001B}[0m Comprehensive discussion covering the full lifecycle of
         building a production REST API with Swift and Vapor. Topics
         included framework setup, PostgreSQL database with Fluent ORM,
         authentication patterns, testing strategies, deployment options
         (Railway, Docker), and security/performance best practices.
\u{001B}[1mTopics:\u{001B}[0m Vapor, REST API, PostgreSQL, Fluent, JWT, Docker, Testing
\u{001B}[1mParticipants:\u{001B}[0m User, Assistant
\u{001B}[1mMessage Count:\u{001B}[0m \(technicalChat.count)
\u{001B}[1mChunk Summaries:\u{001B}[0m 3 stored
""")

// MARK: - Demo 3: Multi-Participant Group Chat

printHeader("DEMO 3: Multi-Participant Group Chat")

printSubheader("Input: \(groupChat.count) messages")
print(formatConversation(groupChat))

printSubheader("Processing")
print("• Message count: \(groupChat.count)")
print("• Strategy: \u{001B}[32mSingle-pass\u{001B}[0m")
let participants = Set(groupChat.compactMap { $0.sender })
print("• Participants detected: \(participants.sorted().joined(separator: ", "))")

printSubheader("Generated Summary")
print("""
\u{001B}[1mTitle:\u{001B}[0m Sprint Planning Coordination
\u{001B}[1mSummary:\u{001B}[0m Team coordinated sprint planning meeting, rescheduling
         from original time to 2pm due to Carol's customer call.
         Agenda includes reviewing 3 carry-over stories from auth
         integration, velocity charts, and new design system discussion.
         Meeting set for Room B.
\u{001B}[1mTopics:\u{001B}[0m Sprint Planning, Team Sync, Velocity, Design System
\u{001B}[1mParticipants:\u{001B}[0m Alice, Bob, Carol, Dave
\u{001B}[1mMessage Count:\u{001B}[0m \(groupChat.count)
""")

// MARK: - Summary Comparison

printHeader("SUMMARY COMPARISON")

print("""
┌─────────────────────┬──────────┬────────┬──────────────┬─────────────────┐
│ Conversation        │ Messages │ Chunks │ Strategy     │ Participants    │
├─────────────────────┼──────────┼────────┼──────────────┼─────────────────┤
│ SwiftUI Help        │    8     │   1    │ Single-pass  │ User, Assistant │
│ Vapor API Guide     │   45     │   3    │ Chunked      │ User, Assistant │
│ Sprint Planning     │   14     │   1    │ Single-pass  │ Alice,Bob,Carol,│
│                     │          │        │              │ Dave            │
└─────────────────────┴──────────┴────────┴──────────────┴─────────────────┘
""")

print("\n\u{001B}[32;1m✓ Demo complete!\u{001B}[0m")
print("\u{001B}[2mNote: Summaries shown are examples. Real summaries are generated\u{001B}[0m")
print("\u{001B}[2mby the on-device LLM when running in the iOS app.\u{001B}[0m\n")
