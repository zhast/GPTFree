//
//  DebugView.swift
//  chat
//
//  Debug menu for testing summarization with sample conversations
//

import SwiftUI
import FoundationModels

#if DEBUG

struct DebugView: View {
    @EnvironmentObject var conversationStore: ConversationStore
    @Environment(\.dismiss) private var dismiss

    @State private var isSeeding = false
    @State private var isSummarizing = false
    @State private var summaryResults: [SummaryResult] = []
    @State private var errorMessage: String?
    @State private var showingAvailabilityGatePreview = false

    @AppStorage(AppleIntelligenceAvailability.overrideDefaultsKey) private var availabilityOverrideRaw = AppleIntelligenceAvailabilityOverride.system.rawValue

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
                Section("Apple Intelligence") {
                    let systemAvailability = SystemLanguageModel.default.availability
                    let effectiveAvailability = AppleIntelligenceAvailability.effectiveAvailability(system: systemAvailability)

                    LabeledContent("System", value: AppleIntelligenceAvailability.description(systemAvailability))
                    LabeledContent("Effective", value: AppleIntelligenceAvailability.description(effectiveAvailability))

                    Picker("Override", selection: $availabilityOverrideRaw) {
                        ForEach(AppleIntelligenceAvailabilityOverride.allCases) { override in
                            Text(override.title).tag(override.rawValue)
                        }
                    }

                    Button {
                        showingAvailabilityGatePreview = true
                    } label: {
                        Label("Preview Availability Screen", systemImage: "sparkles")
                    }

                    Button {
                        availabilityOverrideRaw = AppleIntelligenceAvailabilityOverride.deviceNotEligible.rawValue
                        showingAvailabilityGatePreview = true
                    } label: {
                        Label("Preview: Device Not Supported", systemImage: "iphone.slash")
                    }

                    Button {
                        availabilityOverrideRaw = AppleIntelligenceAvailabilityOverride.appleIntelligenceNotEnabled.rawValue
                        showingAvailabilityGatePreview = true
                    } label: {
                        Label("Preview: Apple Intelligence Off", systemImage: "sparkles")
                    }

                    Button {
                        availabilityOverrideRaw = AppleIntelligenceAvailabilityOverride.modelNotReady.rawValue
                        showingAvailabilityGatePreview = true
                    } label: {
                        Label("Preview: Model Not Ready", systemImage: "icloud.and.arrow.down")
                    }

                    Button {
                        availabilityOverrideRaw = AppleIntelligenceAvailabilityOverride.system.rawValue
                    } label: {
                        Label("Reset Override", systemImage: "arrow.counterclockwise")
                    }
                }

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
        .sheet(isPresented: $showingAvailabilityGatePreview) {
            AvailabilityGatePreview()
        }
    }

    private struct AvailabilityGatePreview: View {
        @Environment(\.dismiss) private var dismiss
        @AppStorage(AppleIntelligenceAvailability.overrideDefaultsKey) private var availabilityOverrideRaw = AppleIntelligenceAvailabilityOverride.system.rawValue

        var body: some View {
            GenerativeAvailabilityGateView {
                ContentUnavailableView {
                    Label("App Content Placeholder", systemImage: "checkmark.seal")
                } description: {
                    Text("This is what you’d see when Apple Intelligence is available.")
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .safeAreaInset(edge: .top) {
                HStack(spacing: 10) {
                    Picker("Override", selection: $availabilityOverrideRaw) {
                        ForEach(AppleIntelligenceAvailabilityOverride.allCases) { override in
                            Text(override.title).tag(override.rawValue)
                        }
                    }
                    .labelsHidden()

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Seeding Functions

    private func seedShortConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        let messages: [(String, Bool)] = [
            ("hey im trying to learn swiftui where should i start", true),
            ("Great choice! I'd recommend starting with Apple's SwiftUI tutorials. They walk you through building a real app called Landmarks.", false),
            ("that sounds good is swiftui harder than uikit", true),
            ("SwiftUI is actually easier for beginners! It uses a declarative syntax, so you describe what you want rather than how to build it step by step.", false),
            ("what about navigationview i heard its deprecated", true),
            ("Yes, in iOS 16+ you should use NavigationStack instead. It's more powerful and supports type-safe navigation with NavigationPath.", false),
            ("perfect ill start with the tutorials thanks", true),
            ("You're welcome! Feel free to ask if you have more questions.", false)
        ]

        await createConversation(title: "SwiftUI Learning", messages: messages)
    }

    private func seedLongConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        var messages: [(String, Bool)] = []

        // Part 1: Setup
        messages.append(("i need help setting up a rest api in swift", true))
        messages.append(("I can help with that! Are you using Vapor or building something custom?", false))
        messages.append(("i was thinking vapor is it good for production", true))
        messages.append(("Vapor is excellent for production. It's type-safe, fast, and has great async/await support.", false))
        messages.append(("how do i handle authentication", true))
        messages.append(("Vapor has built-in JWT support. You can also use sessions or implement OAuth.", false))

        // Part 2: Database
        messages.append(("what database should i use", true))
        messages.append(("PostgreSQL is the most popular choice with Vapor. Use Fluent ORM for database operations.", false))
        messages.append(("is fluent like coredata", true))
        messages.append(("Similar concept but designed for server-side. It supports migrations, relationships, and async queries.", false))
        messages.append(("can you show me a model example", true))
        messages.append(("Sure! You'd create a class conforming to Model with @ID and @Field property wrappers.", false))
        messages.append(("that looks clean what about validation", true))
        messages.append(("Fluent supports Validatable protocol. You can add rules like .count(5...) for string length.", false))

        // Part 3: API design
        messages.append(("how should i structure my routes", true))
        messages.append(("Group related endpoints together. Use route groups for versioning like /api/v1/users.", false))
        messages.append(("should i use controllers", true))
        messages.append(("Yes! RouteCollection protocol lets you organize routes in controller classes.", false))
        messages.append(("what about error handling", true))
        messages.append(("Vapor has AbortError for HTTP errors. You can throw Abort(.notFound) or create custom errors.", false))

        // Part 4: Testing
        messages.append(("how do i test my api", true))
        messages.append(("Vapor has XCTVapor for testing. You can create a test app instance and make requests.", false))
        messages.append(("can i mock the database", true))
        messages.append(("Yes, use an in-memory SQLite database for tests. Configure it in your test setup.", false))

        // Part 5: Deployment
        messages.append(("where should i deploy", true))
        messages.append(("Popular options: Railway, Render, AWS, or DigitalOcean. Railway is easiest to start.", false))
        messages.append(("do i need docker", true))
        messages.append(("Not required but recommended. Vapor generates a Dockerfile automatically.", false))
        messages.append(("what about environment variables", true))
        messages.append(("Use Environment.get() to read them. Store secrets in .env file locally.", false))

        // Part 6: Performance
        messages.append(("how do i handle high traffic", true))
        messages.append(("Vapor handles concurrent requests well with Swift's async/await. Add caching with Redis.", false))
        messages.append(("should i use connection pooling", true))
        messages.append(("Fluent handles pooling automatically. You can configure pool size in database setup.", false))

        // Part 7: Security
        messages.append(("what security measures should i add", true))
        messages.append(("Rate limiting, CORS configuration, input validation, and HTTPS. Vapor has middleware for these.", false))
        messages.append(("how do i prevent sql injection", true))
        messages.append(("Fluent uses parameterized queries by default, so you're protected.", false))

        // Part 8: Final
        messages.append(("any resources you recommend", true))
        messages.append(("The Vapor docs are great. Also check out PointFree for advanced Swift patterns.", false))
        messages.append(("this has been super helpful", true))
        messages.append(("Glad I could help! Good luck with your API project.", false))
        messages.append(("one more thing should i use async await everywhere", true))
        messages.append(("Yes, Vapor 4 is fully async. Use async versions of Fluent queries for best performance.", false))
        messages.append(("perfect thanks again", true))

        await createConversation(title: "Vapor API Development", messages: messages)
    }

    private func seedMultiTopicConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        var messages: [(String, Bool)] = []

        // Topic 1: Weather
        messages.append(("whats a good way to handle weather data in an app", true))
        messages.append(("You can use WeatherKit for iOS or call OpenWeatherMap API directly.", false))
        messages.append(("does weatherkit require a subscription", true))
        messages.append(("Yes, Apple charges based on API calls. Free tier has 500k calls/month.", false))

        // Topic 2: Switching to fitness
        messages.append(("speaking of health how do i access healthkit data", true))
        messages.append(("Request authorization first, then query HKHealthStore for specific data types.", false))
        messages.append(("can i get step count history", true))
        messages.append(("Yes, use HKStatisticsCollectionQuery with a date range for historical data.", false))
        messages.append(("what about workout routes", true))
        messages.append(("HKWorkoutRoute stores GPS data. You'll need location permissions too.", false))

        // Topic 3: Maps integration
        messages.append(("for showing those routes should i use mapkit", true))
        messages.append(("MapKit is great for iOS. Use MKPolyline to draw the workout route on the map.", false))
        messages.append(("can i customize the map style", true))
        messages.append(("Yes! Use MKMapConfiguration for different styles like standard, hybrid, or satellite.", false))

        // Topic 4: Data persistence
        messages.append(("how should i store user preferences", true))
        messages.append(("UserDefaults for simple settings, or SwiftData for complex data models.", false))
        messages.append(("is swiftdata ready for production", true))
        messages.append(("Yes, it's stable in iOS 17+. It's Apple's modern replacement for CoreData.", false))

        // Topic 5: Notifications
        messages.append(("i want to send workout reminders how do notifications work", true))
        messages.append(("Use UNUserNotificationCenter. You can schedule local notifications or use push via APNs.", false))
        messages.append(("can i include actions in notifications", true))
        messages.append(("Yes, define UNNotificationAction buttons. Users can respond without opening the app.", false))

        // Topic 6: App architecture
        messages.append(("what architecture pattern do you recommend", true))
        messages.append(("MVVM works great with SwiftUI. Consider The Composable Architecture for complex apps.", false))
        messages.append(("is tca overkill for a simple app", true))
        messages.append(("For simple apps, basic MVVM with ObservableObject is usually enough.", false))

        // Wrap up
        messages.append(("this covers everything i needed thanks", true))
        messages.append(("You're welcome! You're building a cool fitness app. Good luck!", false))

        await createConversation(title: "Fitness App Development", messages: messages)
    }

    private func seedDebateConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        var messages: [(String, Bool)] = []

        // Phase 1: User is strongly against TypeScript
        messages.append(("i hate typescript its just javascript with extra steps", true))
        messages.append(("I understand that view. Many developers feel the type annotations add overhead without enough benefit.", false))
        messages.append(("exactly i can write javascript faster without fighting the type system", true))
        messages.append(("Speed is valid. For small scripts or prototypes, plain JS is often more productive.", false))
        messages.append(("and the errors are cryptic union types generics who needs that complexity", true))
        messages.append(("TypeScript errors can be overwhelming at first. The learning curve is real.", false))

        // Phase 2: AI presents counterpoints, user remains skeptical
        messages.append(("some people say it helps with large codebases i dont buy it", true))
        messages.append(("In larger teams, types serve as documentation. New developers understand function contracts without reading implementation.", false))
        messages.append(("comments can do that too why add a whole type system", true))
        messages.append(("Comments can go stale. Types are verified by the compiler, so they stay accurate.", false))
        messages.append(("i guess refactoring is slightly easier with types", true))
        messages.append(("That's where TypeScript shines. Renaming a property updates everywhere, and the compiler catches missed spots.", false))

        // Phase 3: User starts to soften
        messages.append(("okay i tried adding types to one file the autocomplete got way better", true))
        messages.append(("IDE support is a major benefit. IntelliSense becomes much more accurate with type information.", false))
        messages.append(("i also caught a bug where i was passing a string instead of a number", true))
        messages.append(("Runtime errors becoming compile-time errors is the core value proposition.", false))
        messages.append(("maybe its not all bad the strict mode seems excessive though", true))
        messages.append(("You can start with loose settings and gradually increase strictness as you're comfortable.", false))

        // Phase 4: User changes position
        messages.append(("i converted my main module to typescript it actually found three bugs", true))
        messages.append(("That's a common experience. Hidden type mismatches surface during migration.", false))
        messages.append(("i think i was wrong about typescript the initial friction is worth it", true))
        messages.append(("Many developers go through that journey. The benefits compound as the codebase grows.", false))
        messages.append(("whats the best way to learn it properly", true))
        messages.append(("Start with the TypeScript handbook, then practice by converting small projects. Focus on understanding inference first.", false))

        await createConversation(title: "TypeScript Debate", messages: messages)
    }

    private func seedStarInterviewConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        let messages: [(String, Bool)] = [
            ("i have a pm interview next week how do i answer behavioral questions", true),
            ("Use the STAR method: Situation, Task, Action, Result. It structures your answers clearly.", false),
            ("can you break that down more", true),
            ("Situation: Set the context. Task: Your responsibility. Action: What you did specifically. Result: The outcome with metrics if possible.", false),
            ("give me an example for tell me about a conflict", true),
            ("Situation: Two engineers disagreed on API design. Task: As PM, I needed to unblock the team. Action: I facilitated a meeting, had each present pros/cons, then we voted. Result: Decision made in one day, shipped on time.", false),
            ("thats helpful how long should answers be", true),
            ("Aim for 2-3 minutes. Too short lacks detail, too long loses the interviewer.", false),
            ("what if i dont have a perfect example", true),
            ("Use adjacent experiences. Personal projects, school work, or volunteer roles count. Focus on transferable skills.", false),
            ("should i prepare stories in advance", true),
            ("Yes, prepare 5-7 stories that cover: leadership, conflict, failure, success, influence without authority, data-driven decision, and customer focus.", false),
            ("what about the failure question that one scares me", true),
            ("Pick a real failure but focus 70% on what you learned and changed. Show growth mindset, not perfection.", false),
            ("any red flags to avoid", true),
            ("Don't blame others, don't pick trivial examples, and don't say you have no weaknesses. Authenticity matters.", false),
            ("this is super helpful i feel more prepared now", true),
            ("Good luck! Remember, they want to see how you think, not just what you did.", false)
        ]

        await createConversation(title: "STAR Interview Prep", messages: messages)
    }

    private func seedHotTubConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        let messages: [(String, Bool)] = [
            ("thinking about getting a hot tub worth it", true),
            ("Depends on usage. If you'll use it 3+ times weekly, usually worth it. Great for muscle recovery and stress relief.", false),
            ("whats the maintenance like", true),
            ("Weekly: test water, add chemicals. Monthly: clean filters. Quarterly: drain and refill. About 20 mins/week.", false),
            ("chemicals sound complicated", true),
            ("Basic kit: chlorine or bromine, pH balancer, shock treatment. Test strips make it easy. Most people get the hang of it in a month.", false),
            ("in ground vs above ground", true),
            ("Above-ground is cheaper, portable, easier to repair. In-ground looks nicer, adds home value, but costs 3-5x more.", false),
            ("how much does running one cost", true),
            ("Electricity runs $20-50/month depending on usage and insulation quality. Good covers reduce heating costs significantly.", false),
            ("any health benefits actually proven", true),
            ("Yes - improves sleep, reduces muscle soreness, can help arthritis and anxiety. 20 mins before bed is ideal for sleep.", false),
            ("what size should i get", true),
            ("For couples, 2-4 person is fine. For entertaining, 6+ person. Bigger isn't always better - more water to heat and maintain.", false),
            ("alright im convinced any brand recommendations", true),
            ("Hot Spring, Jacuzzi, and Sundance are reliable. Avoid no-name brands. Check local dealers for service availability.", false)
        ]

        await createConversation(title: "Hot Tub Shopping", messages: messages)
    }

    private func seedLaunchVideoConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        let messages: [(String, Bool)] = [
            ("why do some product launch videos go viral while others flop", true),
            ("Usually comes down to: emotional hook in first 3 seconds, clear problem-solution narrative, and shareability factor.", false),
            ("what makes a good hook", true),
            ("Pattern interrupt. Show something unexpected, ask a provocative question, or open with the transformation. Dollar Shave Club's 'our blades are great' worked because it broke expectations.", false),
            ("what about apples approach theyre pretty standard", true),
            ("Apple earned the right to be minimal. They built anticipation over decades. For new products, you need to work harder to capture attention.", false),
            ("how long should a launch video be", true),
            ("60-90 seconds for social, 2-3 minutes for landing pages. Attention drops sharply after 2 minutes unless content is exceptional.", false),
            ("should i show the product immediately", true),
            ("Depends. B2C: show it early. B2B: lead with the pain point first, then reveal solution. People need to feel the problem before caring about the fix.", false),
            ("music matters right", true),
            ("Huge impact. Upbeat builds energy, cinematic creates gravitas. Match the emotion you want. Avoid generic stock music - it signals low effort.", false),
            ("what about testimonials in launch videos", true),
            ("Social proof works but keep them short. 5-10 second clips. Long testimonials kill pacing. Save detailed case studies for follow-up content.", false),
            ("any metrics on what works", true),
            ("Videos with faces get 30% more engagement. Questions in titles increase clicks. Captions are essential - 85% watch without sound.", false),
            ("should i hire a production company", true),
            ("For flagship launches, yes. For iterative content, learn to make decent videos yourself. Smartphone + good lighting + clear audio beats expensive but soulless production.", false),
            ("this gives me a lot to think about", true),
            ("Start with the story you want to tell, then figure out production. Story first, polish second.", false)
        ]

        await createConversation(title: "Launch Video Strategy", messages: messages)
    }

    private func seedB2BSaasConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        let messages: [(String, Bool)] = [
            ("everyone talks about exciting startups what are some boring b2b saas ideas that actually make money", true),
            ("The most profitable SaaS is often invisible. Invoice processing, compliance tracking, fleet management. Boring problems, recurring revenue.", false),
            ("why does boring work so well", true),
            ("Less competition, stickier customers, buyers care about ROI not hype. A CFO buying expense software doesn't need it to be cool.", false),
            ("give me some specific examples", true),
            ("Dental practice management, HVAC scheduling software, property management tools, church management systems. Each is a $100M+ market.", false),
            ("church management software really", true),
            ("Yep. Donations, member databases, event scheduling, volunteer coordination. Planning Center does $50M+ ARR. Nobody talks about it.", false),
            ("how do you find these niches", true),
            ("Look for industries using spreadsheets or legacy software. Talk to people who run small businesses. Their pain points are gold.", false),
            ("what about competition from big players", true),
            ("Enterprise software is bloated and expensive. SMBs get ignored. A focused tool that does one thing well beats Salesforce for a plumber.", false),
            ("pricing for boring saas", true),
            ("$50-500/month per seat is common. Value-based pricing works. If you save them 10 hours/month, charge for that value.", false),
            ("how do you market something boring", true),
            ("Direct outreach, industry conferences, partnerships with consultants. SEO for specific pain points. 'Boring' means your customers search for solutions.", false),
            ("any red flags in picking a niche", true),
            ("Avoid dying industries, avoid niches where customers can't pay, avoid markets dominated by one free tool.", false),
            ("whats your top boring saas pick right now", true),
            ("Compliance software for any regulated industry. Healthcare, finance, food service. Regulations only increase, never decrease.", false),
            ("this is actually really helpful i was chasing shiny ideas", true),
            ("Shiny is fun but boring pays the bills. Find a $10K problem and charge $100/month to solve it.", false)
        ]

        await createConversation(title: "Boring B2B SaaS Ideas", messages: messages)
    }

    private func seedClutchConversation() async {
        isSeeding = true
        defer { isSeeding = false }

        let messages: [(String, Bool)] = [
            ("im learning to drive manual the clutch is confusing me", true),
            ("The clutch connects engine to wheels. Pressed in = disconnected. Released = connected. You control how smoothly power transfers.", false),
            ("why do i keep stalling", true),
            ("Releasing clutch too fast without enough gas. The engine needs fuel to handle the load. Think of it like a handshake - gradual meeting in the middle.", false),
            ("whats the bite point", true),
            ("The spot where clutch starts engaging. You'll feel the car want to move and hear RPMs drop slightly. Practice finding it without gas first.", false),
            ("should i use the handbrake on hills", true),
            ("Yes, especially while learning. Handbrake holds car, find bite point, add gas, release handbrake. Prevents rolling back.", false),
            ("my left leg gets tired is that normal", true),
            ("At first, yes. You're using muscles differently. Don't rest your foot on the clutch while driving - causes wear and fatigue.", false),
            ("when do i shift gears", true),
            ("Listen to the engine. High pitch = shift up. Lugging/struggling = shift down. Most cars: 2nd at 15mph, 3rd at 25, 4th at 35, 5th at 45+.", false),
            ("do i need to match revs when downshifting", true),
            ("For smooth driving, yes. Blip the throttle while clutch is in. For normal driving, releasing clutch slowly works too.", false),
            ("whats heel toe shifting", true),
            ("Advanced technique: brake with toe, blip gas with heel, downshift. Used in performance driving. Don't worry about it while learning.", false),
            ("how do i start on a steep hill", true),
            ("More gas than usual, higher bite point. Some people use the e-brake method: engage handbrake, find bite, release brake as you add gas.", false),
            ("is it bad to ride the clutch in traffic", true),
            ("Yes, causes wear. In slow traffic, better to creep in first gear or stop completely. Avoid holding the car on a hill with clutch.", false),
            ("how long until this feels natural", true),
            ("Most people feel comfortable after 10-20 hours of practice. Stick with it - muscle memory takes over and you won't think about it.", false),
            ("any tips for practicing", true),
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

#endif
