//
//  SummaryTestRunner.swift
//  chat
//
//  Automated test runner for summarization - triggered via launch argument
//

import Foundation

/// Results structure written to JSON file for external reading
struct TestRunResults: Codable {
    let timestamp: Date
    let totalTests: Int
    let passedTests: Int
    let results: [SingleTestResult]
}

struct SingleTestResult: Codable {
    let testName: String
    let messageCount: Int
    let chunksUsed: Int
    let durationSeconds: Double
    let generatedTitle: String
    let generatedSummary: String
    let keyTopics: [String]
    let participants: [String]
    let chunkSummaries: [String]?
    let passed: Bool
    let notes: String
}

actor SummaryTestRunner {
    static let shared = SummaryTestRunner()

    private let resultsPath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("summary_test_results.json")
    }()

    private init() {}

    // MARK: - Main Entry Point

    func runAllTests() async {
        print("[TestRunner] Starting automated summary tests...")

        var results: [SingleTestResult] = []

        // Original test cases
        results.append(await runTest(name: "Short Chat (SwiftUI)", messages: TestCases.shortSwiftUI))
        results.append(await runTest(name: "Debate (TypeScript)", messages: TestCases.debateTypeScript))
        results.append(await runTest(name: "Quick Q&A (Git Commands)", messages: TestCases.quickQAGit))
        results.append(await runTest(name: "Troubleshooting (Build Errors)", messages: TestCases.troubleshootingBuild))

        // New diverse test cases
        results.append(await runTest(name: "STAR Interview Method", messages: TestCases.starInterviewMethod))
        results.append(await runTest(name: "Hot Tubs and Relaxation", messages: TestCases.hotTubsRelaxation))
        results.append(await runTest(name: "Launch Video Popularity", messages: TestCases.launchVideoPopularity))
        results.append(await runTest(name: "Boring B2B SaaS Ideas", messages: TestCases.boringB2BSaas))
        results.append(await runTest(name: "Clutch Basics Manual Cars", messages: TestCases.clutchBasicsManual))

        let passed = results.filter { $0.passed }.count
        let runResults = TestRunResults(
            timestamp: Date(),
            totalTests: results.count,
            passedTests: passed,
            results: results
        )

        // Write results to file
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(runResults)
            try data.write(to: resultsPath)
            print("[TestRunner] Results written to: \(resultsPath.path)")
        } catch {
            print("[TestRunner] Failed to write results: \(error)")
        }

        print("[TestRunner] Completed: \(passed)/\(results.count) tests passed")
    }

    // MARK: - Test Execution

    private func runTest(name: String, messages: [(String, Bool)]) async -> SingleTestResult {
        print("[TestRunner] Running: \(name) (\(messages.count) messages)")

        let messageItems = messages.enumerated().map { index, msg in
            MessageItem(
                conversationId: UUID(),
                text: msg.0,
                fromUser: msg.1,
                timestamp: Date().addingTimeInterval(Double(index) * 2)
            )
        }

        let startTime = Date()

        do {
            let summary = try await SummaryGenerationService.shared.generateSummary(from: messageItems)
            let duration = Date().timeIntervalSince(startTime)

            // Basic quality checks
            let titleOk = summary.generatedTitle.count >= 5 && summary.generatedTitle.count <= 50
            let summaryOk = !summary.summaryText.isEmpty && summary.summaryText.count <= 500
            let topicsOk = !summary.keyTopics.isEmpty && summary.keyTopics.count <= 8
            let noFlowery = !containsFloweryLanguage(summary.summaryText)

            let passed = titleOk && summaryOk && topicsOk && noFlowery

            var notes = ""
            if !titleOk { notes += "Title length issue. " }
            if !summaryOk { notes += "Summary length issue. " }
            if !topicsOk { notes += "Topics count issue. " }
            if !noFlowery { notes += "Contains flowery language. " }
            if notes.isEmpty { notes = "OK" }

            return SingleTestResult(
                testName: name,
                messageCount: messages.count,
                chunksUsed: summary.chunkSummaries?.count ?? 1,
                durationSeconds: duration,
                generatedTitle: summary.generatedTitle,
                generatedSummary: summary.summaryText,
                keyTopics: summary.keyTopics,
                participants: summary.participants,
                chunkSummaries: summary.chunkSummaries,
                passed: passed,
                notes: notes
            )
        } catch {
            return SingleTestResult(
                testName: name,
                messageCount: messages.count,
                chunksUsed: 0,
                durationSeconds: Date().timeIntervalSince(startTime),
                generatedTitle: "ERROR",
                generatedSummary: error.localizedDescription,
                keyTopics: [],
                participants: [],
                chunkSummaries: nil,
                passed: false,
                notes: "Exception: \(error.localizedDescription)"
            )
        }
    }

    private func containsFloweryLanguage(_ text: String) -> Bool {
        let floweryWords = [
            "comprehensive", "guiding stars", "journey", "delved", "explored",
            "tackled", "mastering", "deep dive", "incredible", "amazing",
            "wonderful", "fantastic", "brilliant"
        ]
        let lower = text.lowercased()
        return floweryWords.contains { lower.contains($0) }
    }
}

// MARK: - Test Cases

enum TestCases {

    // Test 1: Short conversation (8 messages) - single pass
    static let shortSwiftUI: [(String, Bool)] = [
        ("Hi! I'm trying to learn SwiftUI. Where should I start?", true),
        ("Start with Apple's SwiftUI tutorials. They walk you through building Landmarks app.", false),
        ("Is SwiftUI harder than UIKit?", true),
        ("SwiftUI is easier for beginners. Declarative syntax means you describe what you want.", false),
        ("What about NavigationView? I heard it's deprecated.", true),
        ("Use NavigationStack instead in iOS 16+. It supports type-safe navigation.", false),
        ("Perfect, I'll start with the tutorials. Thanks!", true),
        ("You're welcome! Ask if you have more questions.", false)
    ]

    // Test 2: Long conversation (45 messages) - chunked
    static let longVaporAPI: [(String, Bool)] = {
        var msgs: [(String, Bool)] = []
        msgs.append(("I need help setting up a REST API in Swift", true))
        msgs.append(("Are you using Vapor or building something custom?", false))
        msgs.append(("Vapor. Is it production-ready?", true))
        msgs.append(("Yes, Vapor is excellent. Type-safe, fast, great async/await support.", false))
        msgs.append(("How do I handle authentication?", true))
        msgs.append(("Built-in JWT support. Also sessions or OAuth.", false))
        msgs.append(("What database should I use?", true))
        msgs.append(("PostgreSQL is most popular. Use Fluent ORM.", false))
        msgs.append(("Is Fluent like CoreData?", true))
        msgs.append(("Similar but for server-side. Supports migrations and async queries.", false))
        msgs.append(("Show me a model example?", true))
        msgs.append(("Create a class with Model, use @ID and @Field wrappers.", false))
        msgs.append(("What about validation?", true))
        msgs.append(("Validatable protocol. Rules like .count(5...) for length.", false))
        msgs.append(("How should I structure routes?", true))
        msgs.append(("Group related endpoints. Use /api/v1/users for versioning.", false))
        msgs.append(("Should I use controllers?", true))
        msgs.append(("Yes, RouteCollection protocol organizes routes in classes.", false))
        msgs.append(("Error handling?", true))
        msgs.append(("AbortError for HTTP errors. Throw Abort(.notFound).", false))
        msgs.append(("How do I test my API?", true))
        msgs.append(("XCTVapor for testing. Create test app and make requests.", false))
        msgs.append(("Can I mock the database?", true))
        msgs.append(("Use in-memory SQLite for tests.", false))
        msgs.append(("Where should I deploy?", true))
        msgs.append(("Railway, Render, AWS, DigitalOcean. Railway is easiest.", false))
        msgs.append(("Do I need Docker?", true))
        msgs.append(("Recommended but not required. Vapor generates Dockerfile.", false))
        msgs.append(("Environment variables?", true))
        msgs.append(("Environment.get() to read. Store in .env locally.", false))
        msgs.append(("High traffic handling?", true))
        msgs.append(("Swift async/await handles concurrency well. Add Redis caching.", false))
        msgs.append(("Connection pooling?", true))
        msgs.append(("Fluent handles automatically. Configure pool size in setup.", false))
        msgs.append(("Security measures?", true))
        msgs.append(("Rate limiting, CORS, input validation, HTTPS. Vapor has middleware.", false))
        msgs.append(("SQL injection prevention?", true))
        msgs.append(("Fluent uses parameterized queries by default.", false))
        msgs.append(("Any resources?", true))
        msgs.append(("Vapor docs are great. PointFree for advanced patterns.", false))
        msgs.append(("This was helpful!", true))
        msgs.append(("Good luck with your API!", false))
        msgs.append(("Should I use async/await everywhere?", true))
        msgs.append(("Yes, Vapor 4 is fully async. Use async Fluent queries.", false))
        msgs.append(("Thanks again!", true))
        return msgs
    }()

    // Test 3: Multi-topic conversation (30 messages)
    static let multiTopicFitness: [(String, Bool)] = [
        ("How do I handle weather data in an app?", true),
        ("Use WeatherKit or OpenWeatherMap API.", false),
        ("Does WeatherKit need subscription?", true),
        ("Yes, charges based on API calls. 500k free/month.", false),
        ("How do I access HealthKit data?", true),
        ("Request authorization, query HKHealthStore.", false),
        ("Can I get step history?", true),
        ("HKStatisticsCollectionQuery with date range.", false),
        ("Workout routes?", true),
        ("HKWorkoutRoute has GPS. Need location permissions.", false),
        ("Should I use MapKit for routes?", true),
        ("Yes, MKPolyline draws routes on map.", false),
        ("Custom map styles?", true),
        ("MKMapConfiguration for standard, hybrid, satellite.", false),
        ("How to store preferences?", true),
        ("UserDefaults for simple, SwiftData for complex.", false),
        ("Is SwiftData production ready?", true),
        ("Yes in iOS 17+. Replaces CoreData.", false),
        ("I want workout reminders. Notifications?", true),
        ("UNUserNotificationCenter. Schedule local or use APNs.", false),
        ("Actions in notifications?", true),
        ("UNNotificationAction buttons. Respond without opening app.", false),
        ("Architecture pattern?", true),
        ("MVVM with SwiftUI. TCA for complex apps.", false),
        ("Is TCA overkill?", true),
        ("For simple apps, basic MVVM is enough.", false),
        ("This covers everything. Thanks!", true),
        ("Good luck with your fitness app!", false),
        ("One more - watchOS support?", true),
        ("Share HealthKit data via iCloud. WatchConnectivity for real-time.", false)
    ]

    // Test 4: Debate with sentiment change (24 messages)
    static let debateTypeScript: [(String, Bool)] = [
        ("I hate TypeScript. Just JavaScript with extra steps.", true),
        ("Many developers feel type annotations add overhead.", false),
        ("I write JavaScript faster without fighting types.", true),
        ("For small scripts, plain JS is more productive.", false),
        ("Errors are cryptic. Union types, generics - unnecessary.", true),
        ("TypeScript errors can be overwhelming at first.", false),
        ("People say it helps large codebases. I don't buy it.", true),
        ("Types serve as documentation. New devs understand contracts.", false),
        ("Comments do that. Why add a type system?", true),
        ("Comments go stale. Types are compiler-verified.", false),
        ("Refactoring is slightly easier with types I guess...", true),
        ("Renaming propagates everywhere. Compiler catches misses.", false),
        ("I tried adding types. Autocomplete got better.", true),
        ("IDE support is a major benefit with types.", false),
        ("Caught a bug - string instead of number.", true),
        ("Runtime errors become compile-time errors.", false),
        ("Maybe not all bad. Strict mode seems excessive.", true),
        ("Start loose, increase strictness gradually.", false),
        ("Converted my main module. Found three bugs.", true),
        ("Hidden type mismatches surface during migration.", false),
        ("I was wrong about TypeScript. Friction is worth it.", true),
        ("Many developers go through that journey.", false),
        ("Best way to learn properly?", true),
        ("TypeScript handbook, then convert small projects.", false)
    ]

    // Test 5: Technical deep-dive (35 messages)
    static let technicalCoreData: [(String, Bool)] = [
        ("CoreData vs SwiftData - which should I use?", true),
        ("SwiftData for new iOS 17+ projects. CoreData for legacy.", false),
        ("Can they coexist?", true),
        ("Yes, you can migrate gradually. Same underlying store.", false),
        ("How does SwiftData handle relationships?", true),
        ("Use @Relationship macro. Supports one-to-many, many-to-many.", false),
        ("What about cascading deletes?", true),
        ("deleteRule parameter: .cascade, .nullify, .deny.", false),
        ("Fetching with predicates?", true),
        ("@Query macro with #Predicate. Type-safe filtering.", false),
        ("Can I do complex queries?", true),
        ("Yes, compound predicates, sorting, limiting all supported.", false),
        ("Background context for heavy operations?", true),
        ("ModelActor for background work. Automatic thread safety.", false),
        ("Migration strategy?", true),
        ("Lightweight automatic for simple changes. Custom for complex.", false),
        ("CloudKit sync?", true),
        ("Built-in with ModelConfiguration. Set cloudKitDatabase.", false),
        ("Conflict resolution?", true),
        ("Last-writer-wins by default. Custom merge policies possible.", false),
        ("Performance for large datasets?", true),
        ("Use batch operations. Fetch in pages with fetchLimit/offset.", false),
        ("Indexing?", true),
        ("@Attribute(.indexed) for frequently queried properties.", false),
        ("Memory management?", true),
        ("Faulting automatic. Large objects stay on disk until accessed.", false),
        ("Undo support?", true),
        ("UndoManager integration built-in with modelContext.", false),
        ("Testing with SwiftData?", true),
        ("In-memory ModelConfiguration for tests. Fast, isolated.", false),
        ("Any gotchas?", true),
        ("Watch for retain cycles in relationships. Use weak references.", false),
        ("Thanks, very thorough!", true),
        ("SwiftData documentation is good. WWDC23 videos too.", false),
        ("One more - encryption?", true)
    ]

    // Test 6: Quick Q&A (6 messages) - very short
    static let quickQAGit: [(String, Bool)] = [
        ("How do I undo my last commit?", true),
        ("git reset --soft HEAD~1 keeps changes staged. --hard discards.", false),
        ("What if I already pushed?", true),
        ("git revert HEAD creates a new commit undoing changes. Safer.", false),
        ("Got it, thanks!", true),
        ("Be careful with force push on shared branches.", false)
    ]

    // Test 7: Troubleshooting conversation (20 messages)
    static let troubleshootingBuild: [(String, Bool)] = [
        ("My Xcode build is failing with module not found.", true),
        ("Which module? Check if it's in Package.swift dependencies.", false),
        ("It's Alamofire. Added it via SPM.", true),
        ("Try File > Packages > Reset Package Caches.", false),
        ("Still failing. Same error.", true),
        ("Delete DerivedData folder. ~/Library/Developer/Xcode/DerivedData", false),
        ("Deleted. Now getting different error - linker issue.", true),
        ("Check Build Phases > Link Binary. Is framework listed?", false),
        ("It's not there. How do I add it?", true),
        ("Should be automatic with SPM. Try removing and re-adding package.", false),
        ("Removed and added back. Linker error gone but now crash.", true),
        ("What's the crash? Check console for details.", false),
        ("EXC_BAD_ACCESS in Alamofire request.", true),
        ("Are you using it from background thread? Check thread safety.", false),
        ("Was calling from background. Moved to main - works now.", true),
        ("Network callbacks need main thread for UI updates.", false),
        ("Makes sense. Build works but slow now.", true),
        ("Check for debug symbols, enable incremental builds.", false),
        ("Enabled. Much faster. Thanks for the help!", true),
        ("Clean builds occasionally if issues return.", false)
    ]

    // Test 8: Opinion change about frameworks (22 messages)
    static let opinionChangeFrameworks: [(String, Bool)] = [
        ("React is overrated. Vue is simpler and better.", true),
        ("Vue has great developer experience. React has larger ecosystem.", false),
        ("Ecosystem doesn't matter if code is verbose.", true),
        ("React's verbosity decreased with hooks. Less boilerplate now.", false),
        ("Hooks are confusing. useEffect is a mess.", true),
        ("useEffect has a learning curve. Rules of hooks help.", false),
        ("Vue's composition API is cleaner.", true),
        ("Similar concepts actually. Both moving toward composition.", false),
        ("React needs too many dependencies for basics.", true),
        ("True, React is minimal. Vue is more batteries-included.", false),
        ("Started a React project. TypeScript support is good.", true),
        ("React + TypeScript is very popular. Good tooling.", false),
        ("Found a great component library. Saved lots of time.", true),
        ("Ecosystem benefits showing. More choices available.", false),
        ("Performance is better than expected.", true),
        ("Virtual DOM optimizations are mature now.", false),
        ("Maybe React isn't that bad for large apps.", true),
        ("Both are solid choices. Context matters more than framework.", false),
        ("Team knows React better. Sticking with it.", true),
        ("Team familiarity is often the deciding factor.", false),
        ("Changed my mind. React works well for us.", true),
        ("Good to evaluate options and choose what fits.", false)
    ]

    // Test 9: STAR Interview Method (18 messages)
    static let starInterviewMethod: [(String, Bool)] = [
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

    // Test 10: Hot Tubs and Relaxation (16 messages)
    static let hotTubsRelaxation: [(String, Bool)] = [
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

    // Test 11: Launch Video Popularity (20 messages)
    static let launchVideoPopularity: [(String, Bool)] = [
        ("Why do some product launch videos go viral while others flop?", true),
        ("Usually comes down to: emotional hook in first 3 seconds, clear problem-solution narrative, and shareability factor.", false),
        ("What makes a good hook?", true),
        ("Pattern interrupt. Show something unexpected, ask a provocative question, or open with the transformation. Dollar Shave Club's 'our blades are f***ing great' worked because it broke expectations.", false),
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

    // Test 12: Boring B2B SaaS Ideas (22 messages)
    static let boringB2BSaas: [(String, Bool)] = [
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

    // Test 13: Clutch Basics for Manual Cars (24 messages)
    static let clutchBasicsManual: [(String, Bool)] = [
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
}
