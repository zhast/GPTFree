//
//  DebugView.swift
//  chat
//
//  Debug menu for testing summarization with sample conversations
//

import SwiftUI

struct DebugView: View {
    @EnvironmentObject var conversationStore: ConversationStore
    @Environment(\.dismiss) private var dismiss

    @State private var isSeeding = false
    @State private var isSummarizing = false
    @State private var summaryResults: [SummaryResult] = []
    @State private var errorMessage: String?

    struct SummaryResult: Identifiable {
        let id = UUID()
        let conversationTitle: String
        let messageCount: Int
        let chunksUsed: Int
        let summary: ConversationSummary
        let duration: TimeInterval
    }

    var body: some View {
        NavigationStack {
            List {
                // Seed Section
                Section("Seed Test Conversations") {
                    Button {
                        Task { await seedShortConversation() }
                    } label: {
                        Label("Short Chat (8 msgs)", systemImage: "bubble.left.and.bubble.right")
                    }
                    .disabled(isSeeding)

                    Button {
                        Task { await seedLongConversation() }
                    } label: {
                        Label("Long Chat (45 msgs)", systemImage: "text.bubble")
                    }
                    .disabled(isSeeding)

                    Button {
                        Task { await seedMultiTopicConversation() }
                    } label: {
                        Label("Multi-Topic Chat (30 msgs)", systemImage: "list.bullet")
                    }
                    .disabled(isSeeding)

                    Button {
                        Task { await seedAllTestConversations() }
                    } label: {
                        Label("Seed All Test Chats", systemImage: "square.stack.3d.up")
                    }
                    .disabled(isSeeding)
                }

                // Summarization Section
                Section("Test Summarization") {
                    Button {
                        Task { await summarizeAllConversations() }
                    } label: {
                        HStack {
                            Label("Summarize All Chats", systemImage: "sparkles")
                            if isSummarizing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSummarizing || conversationStore.conversations.isEmpty)
                }

                // Results Section
                if !summaryResults.isEmpty {
                    Section("Summary Results") {
                        ForEach(summaryResults) { result in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(result.conversationTitle)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(result.messageCount) msgs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if result.chunksUsed > 1 {
                                    Text("Chunked: \(result.chunksUsed) chunks")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                } else {
                                    Text("Single-pass")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }

                                Divider()

                                Group {
                                    Text("Title: ").bold() + Text(result.summary.generatedTitle)
                                }
                                .font(.subheadline)

                                Group {
                                    Text("Summary: ").bold() + Text(result.summary.summaryText)
                                }
                                .font(.subheadline)

                                Group {
                                    Text("Topics: ").bold() + Text(result.summary.keyTopics.joined(separator: ", "))
                                }
                                .font(.caption)

                                Group {
                                    Text("Participants: ").bold() + Text(result.summary.participants.joined(separator: ", "))
                                }
                                .font(.caption)

                                if let chunks = result.summary.chunkSummaries, !chunks.isEmpty {
                                    Divider()
                                    Text("Chunk Summaries:")
                                        .font(.caption)
                                        .bold()
                                    ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                                        Text("Chunk \(index + 1): \(chunk)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                HStack {
                                    Spacer()
                                    Text(String(format: "%.2fs", result.duration))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Error Section
                if let error = errorMessage {
                    Section("Error") {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                // Clear Section
                Section {
                    Button(role: .destructive) {
                        summaryResults.removeAll()
                        errorMessage = nil
                    } label: {
                        Label("Clear Results", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        Task { await deleteAllConversations() }
                    } label: {
                        Label("Delete All Conversations", systemImage: "trash.fill")
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Seeding Functions

    private func seedShortConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        let messages: [(String, Bool)] = [
            ("Hi! I'm trying to learn SwiftUI. Where should I start?", true),
            ("Great choice! I'd recommend starting with Apple's SwiftUI tutorials. They walk you through building a real app called Landmarks.", false),
            ("That sounds good. Is SwiftUI harder than UIKit?", true),
            ("SwiftUI is actually easier for beginners! It uses a declarative syntax, so you describe what you want rather than how to build it step by step.", false),
            ("What about NavigationView? I heard it's deprecated.", true),
            ("Yes, in iOS 16+ you should use NavigationStack instead. It's more powerful and supports type-safe navigation with NavigationPath.", false),
            ("Perfect, I'll start with the tutorials. Thanks!", true),
            ("You're welcome! Feel free to ask if you have more questions.", false)
        ]

        await createConversation(title: "SwiftUI Learning", messages: messages)
    }

    private func seedLongConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        var messages: [(String, Bool)] = []

        // Part 1: Setup
        messages.append(("I need help setting up a REST API in Swift", true))
        messages.append(("I can help with that! Are you using Vapor or building something custom?", false))
        messages.append(("I was thinking Vapor. Is it good for production?", true))
        messages.append(("Vapor is excellent for production. It's type-safe, fast, and has great async/await support.", false))
        messages.append(("How do I handle authentication?", true))
        messages.append(("Vapor has built-in JWT support. You can also use sessions or implement OAuth.", false))

        // Part 2: Database
        messages.append(("What database should I use?", true))
        messages.append(("PostgreSQL is the most popular choice with Vapor. Use Fluent ORM for database operations.", false))
        messages.append(("Is Fluent like CoreData?", true))
        messages.append(("Similar concept but designed for server-side. It supports migrations, relationships, and async queries.", false))
        messages.append(("Can you show me a model example?", true))
        messages.append(("Sure! You'd create a class conforming to Model with @ID and @Field property wrappers.", false))
        messages.append(("That looks clean. What about validation?", true))
        messages.append(("Fluent supports Validatable protocol. You can add rules like .count(5...) for string length.", false))

        // Part 3: API design
        messages.append(("How should I structure my routes?", true))
        messages.append(("Group related endpoints together. Use route groups for versioning like /api/v1/users.", false))
        messages.append(("Should I use controllers?", true))
        messages.append(("Yes! RouteCollection protocol lets you organize routes in controller classes.", false))
        messages.append(("What about error handling?", true))
        messages.append(("Vapor has AbortError for HTTP errors. You can throw Abort(.notFound) or create custom errors.", false))

        // Part 4: Testing
        messages.append(("How do I test my API?", true))
        messages.append(("Vapor has XCTVapor for testing. You can create a test app instance and make requests.", false))
        messages.append(("Can I mock the database?", true))
        messages.append(("Yes, use an in-memory SQLite database for tests. Configure it in your test setup.", false))

        // Part 5: Deployment
        messages.append(("Where should I deploy?", true))
        messages.append(("Popular options: Railway, Render, AWS, or DigitalOcean. Railway is easiest to start.", false))
        messages.append(("Do I need Docker?", true))
        messages.append(("Not required but recommended. Vapor generates a Dockerfile automatically.", false))
        messages.append(("What about environment variables?", true))
        messages.append(("Use Environment.get() to read them. Store secrets in .env file locally.", false))

        // Part 6: Performance
        messages.append(("How do I handle high traffic?", true))
        messages.append(("Vapor handles concurrent requests well with Swift's async/await. Add caching with Redis.", false))
        messages.append(("Should I use connection pooling?", true))
        messages.append(("Fluent handles pooling automatically. You can configure pool size in database setup.", false))

        // Part 7: Security
        messages.append(("What security measures should I add?", true))
        messages.append(("Rate limiting, CORS configuration, input validation, and HTTPS. Vapor has middleware for these.", false))
        messages.append(("How do I prevent SQL injection?", true))
        messages.append(("Fluent uses parameterized queries by default, so you're protected.", false))

        // Part 8: Final
        messages.append(("Any resources you recommend?", true))
        messages.append(("The Vapor docs are great. Also check out PointFree for advanced Swift patterns.", false))
        messages.append(("This has been super helpful!", true))
        messages.append(("Glad I could help! Good luck with your API project.", false))
        messages.append(("One more thing - should I use async/await everywhere?", true))
        messages.append(("Yes, Vapor 4 is fully async. Use async versions of Fluent queries for best performance.", false))
        messages.append(("Perfect. Thanks again!", true))

        await createConversation(title: "Vapor API Development", messages: messages)
    }

    private func seedMultiTopicConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        var messages: [(String, Bool)] = []

        // Topic 1: Weather
        messages.append(("What's a good way to handle weather data in an app?", true))
        messages.append(("You can use WeatherKit for iOS or call OpenWeatherMap API directly.", false))
        messages.append(("Does WeatherKit require a subscription?", true))
        messages.append(("Yes, Apple charges based on API calls. Free tier has 500k calls/month.", false))

        // Topic 2: Switching to fitness
        messages.append(("Speaking of health, how do I access HealthKit data?", true))
        messages.append(("Request authorization first, then query HKHealthStore for specific data types.", false))
        messages.append(("Can I get step count history?", true))
        messages.append(("Yes, use HKStatisticsCollectionQuery with a date range for historical data.", false))
        messages.append(("What about workout routes?", true))
        messages.append(("HKWorkoutRoute stores GPS data. You'll need location permissions too.", false))

        // Topic 3: Maps integration
        messages.append(("For showing those routes, should I use MapKit?", true))
        messages.append(("MapKit is great for iOS. Use MKPolyline to draw the workout route on the map.", false))
        messages.append(("Can I customize the map style?", true))
        messages.append(("Yes! Use MKMapConfiguration for different styles like standard, hybrid, or satellite.", false))

        // Topic 4: Data persistence
        messages.append(("How should I store user preferences?", true))
        messages.append(("UserDefaults for simple settings, or SwiftData for complex data models.", false))
        messages.append(("Is SwiftData ready for production?", true))
        messages.append(("Yes, it's stable in iOS 17+. It's Apple's modern replacement for CoreData.", false))

        // Topic 5: Notifications
        messages.append(("I want to send workout reminders. How do notifications work?", true))
        messages.append(("Use UNUserNotificationCenter. You can schedule local notifications or use push via APNs.", false))
        messages.append(("Can I include actions in notifications?", true))
        messages.append(("Yes, define UNNotificationAction buttons. Users can respond without opening the app.", false))

        // Topic 6: App architecture
        messages.append(("What architecture pattern do you recommend?", true))
        messages.append(("MVVM works great with SwiftUI. Consider The Composable Architecture for complex apps.", false))
        messages.append(("Is TCA overkill for a simple app?", true))
        messages.append(("For simple apps, basic MVVM with ObservableObject is usually enough.", false))

        // Wrap up
        messages.append(("This covers everything I needed. Thanks!", true))
        messages.append(("You're welcome! You're building a cool fitness app. Good luck!", false))

        await createConversation(title: "Fitness App Development", messages: messages)
    }

    private func seedAllTestConversations() async {
        await seedShortConversation()
        try? await Task.sleep(for: .milliseconds(500))
        await seedLongConversation()
        try? await Task.sleep(for: .milliseconds(500))
        await seedMultiTopicConversation()
    }

    private func createConversation(title: String, messages: [(String, Bool)]) async {
        let conversationId = UUID()
        let now = Date()

        // Create conversation
        let conversation = Conversation(
            id: conversationId,
            title: title,
            createdAt: now,
            updatedAt: now,
            summary: nil,
            messageCount: messages.count
        )

        // Create messages
        let messageItems = messages.enumerated().map { index, msg in
            MessageItem(
                conversationId: conversationId,
                text: msg.0,
                fromUser: msg.1,
                timestamp: now.addingTimeInterval(Double(index) * 2)
            )
        }

        // Save
        do {
            try await PersistenceService.shared.saveMessages(messageItems, for: conversationId)
            conversationStore.conversations.insert(conversation, at: 0)
            try await PersistenceService.shared.saveConversationsIndex(conversationStore.conversations)
        } catch {
            errorMessage = "Failed to seed: \(error.localizedDescription)"
        }
    }

    // MARK: - Summarization

    private func summarizeAllConversations() async {
        isSummarizing = true
        summaryResults.removeAll()
        errorMessage = nil
        defer { isSummarizing = false }

        let summaryService = SummaryGenerationService.shared

        for conversation in conversationStore.conversations {
            do {
                let messages = try await PersistenceService.shared.loadMessages(for: conversation.id)
                guard !messages.isEmpty else { continue }

                let startTime = Date()
                let summary = try await summaryService.generateSummary(from: messages)
                let duration = Date().timeIntervalSince(startTime)

                let result = SummaryResult(
                    conversationTitle: conversation.title,
                    messageCount: messages.count,
                    chunksUsed: summary.chunkSummaries?.count ?? 1,
                    summary: summary,
                    duration: duration
                )

                summaryResults.append(result)

                // Update conversation with summary
                conversationStore.updateSummary(summary, for: conversation.id)

            } catch {
                errorMessage = "Error summarizing \(conversation.title): \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Cleanup

    private func deleteAllConversations() async {
        for conversation in conversationStore.conversations {
            try? await PersistenceService.shared.deleteConversationMessages(for: conversation.id)
        }
        conversationStore.conversations.removeAll()
        try? await PersistenceService.shared.saveConversationsIndex([])
        summaryResults.removeAll()
    }
}

#Preview {
    DebugView()
        .environmentObject(ConversationStore())
}
