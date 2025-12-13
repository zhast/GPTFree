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
                        Task { await seedDebateConversation() }
                    } label: {
                        Label("Debate Chat (24 msgs)", systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(isSeeding)

                    Button {
                        Task { await seedStarInterviewConversation() }
                    } label: {
                        Label("STAR Interview (18 msgs)", systemImage: "star")
                    }
                    .disabled(isSeeding)

                    Button {
                        Task { await seedHotTubConversation() }
                    } label: {
                        Label("Hot Tubs (16 msgs)", systemImage: "drop.fill")
                    }
                    .disabled(isSeeding)

                    Button {
                        Task { await seedLaunchVideoConversation() }
                    } label: {
                        Label("Launch Videos (20 msgs)", systemImage: "play.rectangle")
                    }
                    .disabled(isSeeding)

                    Button {
                        Task { await seedB2BSaasConversation() }
                    } label: {
                        Label("B2B SaaS Ideas (22 msgs)", systemImage: "building.2")
                    }
                    .disabled(isSeeding)

                    Button {
                        Task { await seedClutchConversation() }
                    } label: {
                        Label("Manual Car Clutch (24 msgs)", systemImage: "car")
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

    private func seedDebateConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        var messages: [(String, Bool)] = []

        // Phase 1: User is strongly against TypeScript
        messages.append(("I hate TypeScript. It's just JavaScript with extra steps.", true))
        messages.append(("I understand that view. Many developers feel the type annotations add overhead without enough benefit.", false))
        messages.append(("Exactly! I can write JavaScript faster without fighting the type system.", true))
        messages.append(("Speed is valid. For small scripts or prototypes, plain JS is often more productive.", false))
        messages.append(("And the errors are cryptic. Union types, generics - who needs that complexity?", true))
        messages.append(("TypeScript errors can be overwhelming at first. The learning curve is real.", false))

        // Phase 2: AI presents counterpoints, user remains skeptical
        messages.append(("Some people say it helps with large codebases. I don't buy it.", true))
        messages.append(("In larger teams, types serve as documentation. New developers understand function contracts without reading implementation.", false))
        messages.append(("Comments can do that too. Why add a whole type system?", true))
        messages.append(("Comments can go stale. Types are verified by the compiler, so they stay accurate.", false))
        messages.append(("I guess refactoring is slightly easier with types...", true))
        messages.append(("That's where TypeScript shines. Renaming a property updates everywhere, and the compiler catches missed spots.", false))

        // Phase 3: User starts to soften
        messages.append(("Okay, I tried adding types to one file. The autocomplete got way better.", true))
        messages.append(("IDE support is a major benefit. IntelliSense becomes much more accurate with type information.", false))
        messages.append(("I also caught a bug where I was passing a string instead of a number.", true))
        messages.append(("Runtime errors becoming compile-time errors is the core value proposition.", false))
        messages.append(("Maybe it's not all bad. The strict mode seems excessive though.", true))
        messages.append(("You can start with loose settings and gradually increase strictness as you're comfortable.", false))

        // Phase 4: User changes position
        messages.append(("I converted my main module to TypeScript. It actually found three bugs.", true))
        messages.append(("That's a common experience. Hidden type mismatches surface during migration.", false))
        messages.append(("I think I was wrong about TypeScript. The initial friction is worth it.", true))
        messages.append(("Many developers go through that journey. The benefits compound as the codebase grows.", false))
        messages.append(("What's the best way to learn it properly?", true))
        messages.append(("Start with the TypeScript handbook, then practice by converting small projects. Focus on understanding inference first.", false))

        await createConversation(title: "TypeScript Debate", messages: messages)
    }

    private func seedStarInterviewConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        let messages: [(String, Bool)] = [
            ("I have a PM interview next week. How do I answer behavioral questions?", true),
            ("Use the STAR method: Situation, Task, Action, Result. It structures your answers clearly.", false),
            ("Can you break that down more?", true),
            ("Situation: Set the context. Task: Your responsibility. Action: What you did specifically. Result: The outcome with metrics if possible.", false),
            ("Give me an example for 'tell me about a conflict'?", true),
            ("Situation: Two engineers disagreed on API design. Task: As PM, I needed to unblock the team. Action: I facilitated a meeting, had each present pros/cons, then we voted. Result: Decision made in one day, shipped on time.", false),
            ("That's helpful. How long should answers be?", true),
            ("Aim for 2-3 minutes. Too short lacks detail, too long loses the interviewer.", false),
            ("What if I don't have a perfect example?", true),
            ("Use adjacent experiences. Personal projects, school work, or volunteer roles count. Focus on transferable skills.", false),
            ("Should I prepare stories in advance?", true),
            ("Yes, prepare 5-7 stories that cover: leadership, conflict, failure, success, influence without authority, data-driven decision, and customer focus.", false),
            ("What about the 'failure' question? That one scares me.", true),
            ("Pick a real failure but focus 70% on what you learned and changed. Show growth mindset, not perfection.", false),
            ("Any red flags to avoid?", true),
            ("Don't blame others, don't pick trivial examples, and don't say you have no weaknesses. Authenticity matters.", false),
            ("This is super helpful. I feel more prepared now.", true),
            ("Good luck! Remember, they want to see how you think, not just what you did.", false)
        ]

        await createConversation(title: "STAR Interview Prep", messages: messages)
    }

    private func seedHotTubConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        let messages: [(String, Bool)] = [
            ("Thinking about getting a hot tub. Worth it?", true),
            ("Depends on usage. If you'll use it 3+ times weekly, usually worth it. Great for muscle recovery and stress relief.", false),
            ("What's the maintenance like?", true),
            ("Weekly: test water, add chemicals. Monthly: clean filters. Quarterly: drain and refill. About 20 mins/week.", false),
            ("Chemicals sound complicated.", true),
            ("Basic kit: chlorine or bromine, pH balancer, shock treatment. Test strips make it easy. Most people get the hang of it in a month.", false),
            ("In-ground vs above-ground?", true),
            ("Above-ground is cheaper, portable, easier to repair. In-ground looks nicer, adds home value, but costs 3-5x more.", false),
            ("How much does running one cost?", true),
            ("Electricity runs $20-50/month depending on usage and insulation quality. Good covers reduce heating costs significantly.", false),
            ("Any health benefits actually proven?", true),
            ("Yes - improves sleep, reduces muscle soreness, can help arthritis and anxiety. 20 mins before bed is ideal for sleep.", false),
            ("What size should I get?", true),
            ("For couples, 2-4 person is fine. For entertaining, 6+ person. Bigger isn't always better - more water to heat and maintain.", false),
            ("Alright, I'm convinced. Any brand recommendations?", true),
            ("Hot Spring, Jacuzzi, and Sundance are reliable. Avoid no-name brands. Check local dealers for service availability.", false)
        ]

        await createConversation(title: "Hot Tub Shopping", messages: messages)
    }

    private func seedLaunchVideoConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        let messages: [(String, Bool)] = [
            ("Why do some product launch videos go viral while others flop?", true),
            ("Usually comes down to: emotional hook in first 3 seconds, clear problem-solution narrative, and shareability factor.", false),
            ("What makes a good hook?", true),
            ("Pattern interrupt. Show something unexpected, ask a provocative question, or open with the transformation. Dollar Shave Club's 'our blades are great' worked because it broke expectations.", false),
            ("What about Apple's approach? They're pretty standard.", true),
            ("Apple earned the right to be minimal. They built anticipation over decades. For new products, you need to work harder to capture attention.", false),
            ("How long should a launch video be?", true),
            ("60-90 seconds for social, 2-3 minutes for landing pages. Attention drops sharply after 2 minutes unless content is exceptional.", false),
            ("Should I show the product immediately?", true),
            ("Depends. B2C: show it early. B2B: lead with the pain point first, then reveal solution. People need to feel the problem before caring about the fix.", false),
            ("Music matters right?", true),
            ("Huge impact. Upbeat builds energy, cinematic creates gravitas. Match the emotion you want. Avoid generic stock music - it signals low effort.", false),
            ("What about testimonials in launch videos?", true),
            ("Social proof works but keep them short. 5-10 second clips. Long testimonials kill pacing. Save detailed case studies for follow-up content.", false),
            ("Any metrics on what works?", true),
            ("Videos with faces get 30% more engagement. Questions in titles increase clicks. Captions are essential - 85% watch without sound.", false),
            ("Should I hire a production company?", true),
            ("For flagship launches, yes. For iterative content, learn to make decent videos yourself. Smartphone + good lighting + clear audio beats expensive but soulless production.", false),
            ("This gives me a lot to think about.", true),
            ("Start with the story you want to tell, then figure out production. Story first, polish second.", false)
        ]

        await createConversation(title: "Launch Video Strategy", messages: messages)
    }

    private func seedB2BSaasConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        let messages: [(String, Bool)] = [
            ("Everyone talks about exciting startups. What are some boring B2B SaaS ideas that actually make money?", true),
            ("The most profitable SaaS is often invisible. Invoice processing, compliance tracking, fleet management. Boring problems, recurring revenue.", false),
            ("Why does boring work so well?", true),
            ("Less competition, stickier customers, buyers care about ROI not hype. A CFO buying expense software doesn't need it to be cool.", false),
            ("Give me some specific examples?", true),
            ("Dental practice management, HVAC scheduling software, property management tools, church management systems. Each is a $100M+ market.", false),
            ("Church management software? Really?", true),
            ("Yep. Donations, member databases, event scheduling, volunteer coordination. Planning Center does $50M+ ARR. Nobody talks about it.", false),
            ("How do you find these niches?", true),
            ("Look for industries using spreadsheets or legacy software. Talk to people who run small businesses. Their pain points are gold.", false),
            ("What about competition from big players?", true),
            ("Enterprise software is bloated and expensive. SMBs get ignored. A focused tool that does one thing well beats Salesforce for a plumber.", false),
            ("Pricing for boring SaaS?", true),
            ("$50-500/month per seat is common. Value-based pricing works. If you save them 10 hours/month, charge for that value.", false),
            ("How do you market something boring?", true),
            ("Direct outreach, industry conferences, partnerships with consultants. SEO for specific pain points. 'Boring' means your customers search for solutions.", false),
            ("Any red flags in picking a niche?", true),
            ("Avoid dying industries, avoid niches where customers can't pay, avoid markets dominated by one free tool.", false),
            ("What's your top boring SaaS pick right now?", true),
            ("Compliance software for any regulated industry. Healthcare, finance, food service. Regulations only increase, never decrease.", false),
            ("This is actually really helpful. I was chasing shiny ideas.", true),
            ("Shiny is fun but boring pays the bills. Find a $10K problem and charge $100/month to solve it.", false)
        ]

        await createConversation(title: "Boring B2B SaaS Ideas", messages: messages)
    }

    private func seedClutchConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        let messages: [(String, Bool)] = [
            ("I'm learning to drive manual. The clutch is confusing me.", true),
            ("The clutch connects engine to wheels. Pressed in = disconnected. Released = connected. You control how smoothly power transfers.", false),
            ("Why do I keep stalling?", true),
            ("Releasing clutch too fast without enough gas. The engine needs fuel to handle the load. Think of it like a handshake - gradual meeting in the middle.", false),
            ("What's the 'bite point'?", true),
            ("The spot where clutch starts engaging. You'll feel the car want to move and hear RPMs drop slightly. Practice finding it without gas first.", false),
            ("Should I use the handbrake on hills?", true),
            ("Yes, especially while learning. Handbrake holds car, find bite point, add gas, release handbrake. Prevents rolling back.", false),
            ("My left leg gets tired. Is that normal?", true),
            ("At first, yes. You're using muscles differently. Don't rest your foot on the clutch while driving - causes wear and fatigue.", false),
            ("When do I shift gears?", true),
            ("Listen to the engine. High pitch = shift up. Lugging/struggling = shift down. Most cars: 2nd at 15mph, 3rd at 25, 4th at 35, 5th at 45+.", false),
            ("Do I need to match revs when downshifting?", true),
            ("For smooth driving, yes. Blip the throttle while clutch is in. For normal driving, releasing clutch slowly works too.", false),
            ("What's heel-toe shifting?", true),
            ("Advanced technique: brake with toe, blip gas with heel, downshift. Used in performance driving. Don't worry about it while learning.", false),
            ("How do I start on a steep hill?", true),
            ("More gas than usual, higher bite point. Some people use the e-brake method: engage handbrake, find bite, release brake as you add gas.", false),
            ("Is it bad to ride the clutch in traffic?", true),
            ("Yes, causes wear. In slow traffic, better to creep in first gear or stop completely. Avoid holding the car on a hill with clutch.", false),
            ("How long until this feels natural?", true),
            ("Most people feel comfortable after 10-20 hours of practice. Stick with it - muscle memory takes over and you won't think about it.", false),
            ("Any tips for practicing?", true),
            ("Empty parking lot, start/stop repeatedly. Practice hill starts. Don't avoid traffic - that's where you really learn. Stay calm when you stall.", false)
        ]

        await createConversation(title: "Learning Manual Transmission", messages: messages)
    }

    private func seedAllTestConversations() async {
        await seedShortConversation()
        try? await Task.sleep(for: .milliseconds(300))
        await seedLongConversation()
        try? await Task.sleep(for: .milliseconds(300))
        await seedMultiTopicConversation()
        try? await Task.sleep(for: .milliseconds(300))
        await seedDebateConversation()
        try? await Task.sleep(for: .milliseconds(300))
        await seedStarInterviewConversation()
        try? await Task.sleep(for: .milliseconds(300))
        await seedHotTubConversation()
        try? await Task.sleep(for: .milliseconds(300))
        await seedLaunchVideoConversation()
        try? await Task.sleep(for: .milliseconds(300))
        await seedB2BSaasConversation()
        try? await Task.sleep(for: .milliseconds(300))
        await seedClutchConversation()
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
