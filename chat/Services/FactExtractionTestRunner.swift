//
//  FactExtractionTestRunner.swift
//  chat
//
//  Automated test runner for fact extraction - triggered via launch argument
//

import Foundation

#if DEBUG

/// Results structure written to JSON file for external reading
struct FactExtractionTestRunResults: Codable {
    let timestamp: Date
    let totalTests: Int
    let passedTests: Int
    let failedTests: Int
    let positiveTestsPassed: Int
    let positiveTestsTotal: Int
    let negativeTestsPassed: Int
    let negativeTestsTotal: Int
    let results: [FactTestResult]
}

struct FactTestResult: Codable {
    let testName: String
    let inputMessage: String
    let expectedToExtract: Bool
    let expectedFact: String?
    let actualHasFact: Bool
    let actualFact: String
    let durationSeconds: Double
    let passed: Bool
    let notes: String
}

actor FactExtractionTestRunner {
    static let shared = FactExtractionTestRunner()

    private let resultsPath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("fact_extraction_test_results.json")
    }()

    private init() {}

    // MARK: - Main Entry Point

    func runAllTests() async {
        print("[FactTestRunner] Starting automated fact extraction tests...")
        print("[FactTestRunner] Results will be written to: \(resultsPath.path)")

        var results: [FactTestResult] = []

        // Run positive tests (should extract)
        print("\n[FactTestRunner] === POSITIVE TESTS (should extract) ===")
        for testCase in FactTestCases.positiveTests {
            let result = await runTest(
                name: testCase.name,
                message: testCase.message,
                expectedToExtract: true,
                expectedFact: testCase.expectedFact
            )
            results.append(result)
        }

        // Run negative tests (should NOT extract)
        print("\n[FactTestRunner] === NEGATIVE TESTS (should NOT extract) ===")
        for testCase in FactTestCases.negativeTests {
            let result = await runTest(
                name: testCase.name,
                message: testCase.message,
                expectedToExtract: false,
                expectedFact: nil
            )
            results.append(result)
        }

        // Run edge case tests
        print("\n[FactTestRunner] === EDGE CASE TESTS ===")
        for testCase in FactTestCases.edgeCaseTests {
            let result = await runTest(
                name: testCase.name,
                message: testCase.message,
                expectedToExtract: testCase.expectedToExtract,
                expectedFact: testCase.expectedFact
            )
            results.append(result)
        }

        // Calculate statistics
        let positiveTests = results.filter { FactTestCases.positiveTests.map { $0.name }.contains($0.testName) }
        let negativeTests = results.filter { FactTestCases.negativeTests.map { $0.name }.contains($0.testName) }

        let passed = results.filter { $0.passed }.count
        let failed = results.count - passed
        let positivePassed = positiveTests.filter { $0.passed }.count
        let negativePassed = negativeTests.filter { $0.passed }.count

        let runResults = FactExtractionTestRunResults(
            timestamp: Date(),
            totalTests: results.count,
            passedTests: passed,
            failedTests: failed,
            positiveTestsPassed: positivePassed,
            positiveTestsTotal: positiveTests.count,
            negativeTestsPassed: negativePassed,
            negativeTestsTotal: negativeTests.count,
            results: results
        )

        // Write results to file
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(runResults)
            try data.write(to: resultsPath)
            print("\n[FactTestRunner] Results written to: \(resultsPath.path)")
        } catch {
            print("[FactTestRunner] Failed to write results: \(error)")
        }

        // Print summary
        print("\n[FactTestRunner] ========== SUMMARY ==========")
        print("[FactTestRunner] Total: \(passed)/\(results.count) passed (\(failed) failed)")
        print("[FactTestRunner] Positive tests: \(positivePassed)/\(positiveTests.count) passed")
        print("[FactTestRunner] Negative tests: \(negativePassed)/\(negativeTests.count) passed")

        // Print failures
        let failures = results.filter { !$0.passed }
        if !failures.isEmpty {
            print("\n[FactTestRunner] ========== FAILURES ==========")
            for failure in failures {
                print("[FactTestRunner] FAILED: \(failure.testName)")
                print("  Input: \"\(failure.inputMessage)\"")
                print("  Expected to extract: \(failure.expectedToExtract)")
                print("  Actual hasFact: \(failure.actualHasFact)")
                print("  Actual fact: \"\(failure.actualFact)\"")
                print("  Notes: \(failure.notes)")
                print("")
            }
        }
    }

    // MARK: - Test Execution

    private func runTest(
        name: String,
        message: String,
        expectedToExtract: Bool,
        expectedFact: String?
    ) async -> FactTestResult {
        print("[FactTestRunner] Running: \(name)")

        let startTime = Date()

        do {
            let extractedFacts = try await FactExtractionService.shared.extractFactsFromMessage(
                message,
                conversationId: UUID()
            )

            let duration = Date().timeIntervalSince(startTime)
            let hasFact = !extractedFacts.isEmpty
            let actualFact = extractedFacts.first?.content ?? ""

            // Determine if test passed
            let passed: Bool
            var notes: String

            if expectedToExtract {
                // Positive test: should have extracted a fact
                if hasFact {
                    passed = true
                    notes = "OK - Extracted: \"\(actualFact)\""
                } else {
                    passed = false
                    notes = "FAIL - Expected extraction but got nothing"
                }
            } else {
                // Negative test: should NOT have extracted a fact
                if hasFact {
                    passed = false
                    notes = "FAIL - Expected no extraction but got: \"\(actualFact)\""
                } else {
                    passed = true
                    notes = "OK - Correctly ignored"
                }
            }

            let symbol = passed ? "PASS" : "FAIL"
            print("[FactTestRunner] [\(symbol)] \(name): \(notes)")

            return FactTestResult(
                testName: name,
                inputMessage: message,
                expectedToExtract: expectedToExtract,
                expectedFact: expectedFact,
                actualHasFact: hasFact,
                actualFact: actualFact,
                durationSeconds: duration,
                passed: passed,
                notes: notes
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            print("[FactTestRunner] [ERROR] \(name): \(error.localizedDescription)")

            return FactTestResult(
                testName: name,
                inputMessage: message,
                expectedToExtract: expectedToExtract,
                expectedFact: expectedFact,
                actualHasFact: false,
                actualFact: "",
                durationSeconds: duration,
                passed: false,
                notes: "ERROR: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Test Cases

fileprivate struct TestCase {
    let name: String
    let message: String
    let expectedToExtract: Bool
    let expectedFact: String?

    init(name: String, message: String, expectedFact: String) {
        self.name = name
        self.message = message
        self.expectedToExtract = true
        self.expectedFact = expectedFact
    }

    init(name: String, message: String, shouldNotExtract: Bool = true) {
        self.name = name
        self.message = message
        self.expectedToExtract = false
        self.expectedFact = nil
    }
}

fileprivate enum FactTestCases {

    // MARK: - Positive Tests (should extract facts)

    static let positiveTests: [TestCase] = [
        // === PERSONAL INFO ===
        TestCase(name: "Name - Simple", message: "My name is Sarah", expectedFact: "Is named Sarah"),
        TestCase(name: "Name - I'm format", message: "I'm Michael", expectedFact: "Is named Michael"),
        TestCase(name: "Name - Call me", message: "You can call me Alex", expectedFact: "Is named Alex"),
        TestCase(name: "Name - Full name", message: "My full name is Jennifer Martinez", expectedFact: "Is named Jennifer Martinez"),
        TestCase(name: "Age - Years old", message: "I'm 28 years old", expectedFact: "Is 28 years old"),
        TestCase(name: "Age - Turned", message: "I just turned 35 last month", expectedFact: "Is 35 years old"),
        TestCase(name: "Location - City", message: "I live in Austin", expectedFact: "Lives in Austin"),
        TestCase(name: "Location - Country", message: "I'm from Japan", expectedFact: "Is from Japan"),
        TestCase(name: "Location - Moved", message: "I recently moved to Seattle", expectedFact: "Lives in Seattle"),
        TestCase(name: "Location - Born", message: "I was born in London", expectedFact: "Was born in London"),
        TestCase(name: "Nationality", message: "I'm Canadian", expectedFact: "Is Canadian"),

        // === OCCUPATION ===
        TestCase(name: "Job - Nurse", message: "I work as a nurse", expectedFact: "Works as a nurse"),
        TestCase(name: "Job - Developer", message: "I'm a software developer", expectedFact: "Is a software developer"),
        TestCase(name: "Job - Teacher", message: "I teach high school math", expectedFact: "Teaches high school math"),
        TestCase(name: "Job - Company", message: "I work at Microsoft", expectedFact: "Works at Microsoft"),
        TestCase(name: "Job - Industry", message: "I'm in the healthcare industry", expectedFact: "Works in healthcare"),
        TestCase(name: "Job - Freelance", message: "I'm a freelance designer", expectedFact: "Is a freelance designer"),
        TestCase(name: "Job - Own business", message: "I run my own bakery", expectedFact: "Owns a bakery"),
        TestCase(name: "Job - Remote", message: "I work remotely from home", expectedFact: "Works remotely"),
        TestCase(name: "Job - Years exp", message: "I've been a lawyer for 15 years", expectedFact: "Is a lawyer"),

        // === PREFERENCES - LIKES ===
        TestCase(name: "Like - Coffee", message: "I love coffee", expectedFact: "Loves coffee"),
        TestCase(name: "Like - Pizza", message: "I like pizza", expectedFact: "Likes pizza"),
        TestCase(name: "Like - Hot tubs", message: "I like hot tubs", expectedFact: "Likes hot tubs"),
        TestCase(name: "Like - Reading", message: "I enjoy reading sci-fi novels", expectedFact: "Enjoys reading sci-fi"),
        TestCase(name: "Like - Favorite", message: "My favorite color is blue", expectedFact: "Favorite color is blue"),
        TestCase(name: "Like - Prefer", message: "I prefer working at night", expectedFact: "Prefers working at night"),
        TestCase(name: "Like - Really into", message: "I'm really into photography", expectedFact: "Is into photography"),
        TestCase(name: "Like - Passionate", message: "I'm passionate about sustainability", expectedFact: "Is passionate about sustainability"),
        TestCase(name: "Like - Fan of", message: "I'm a huge fan of Star Wars", expectedFact: "Is a fan of Star Wars"),

        // === PREFERENCES - DISLIKES ===
        TestCase(name: "Dislike - Cold", message: "I don't like cold weather", expectedFact: "Dislikes cold weather"),
        TestCase(name: "Dislike - Can't stand", message: "I can't stand loud music", expectedFact: "Dislikes loud music"),
        TestCase(name: "Dislike - Not a fan", message: "I'm not a fan of horror movies", expectedFact: "Dislikes horror movies"),
        TestCase(name: "Dislike - Avoid", message: "I try to avoid spicy food", expectedFact: "Avoids spicy food"),

        // === GOALS ===
        TestCase(name: "Goal - Python", message: "I'm trying to learn Python", expectedFact: "Is learning Python"),
        TestCase(name: "Goal - Marathon", message: "I want to run a marathon", expectedFact: "Wants to run a marathon"),
        TestCase(name: "Goal - Weight loss", message: "I'm trying to lose weight", expectedFact: "Is trying to lose weight"),
        TestCase(name: "Goal - Career", message: "I want to become a product manager", expectedFact: "Wants to become a product manager"),
        TestCase(name: "Goal - Learning", message: "I'm learning to play piano", expectedFact: "Is learning piano"),
        TestCase(name: "Goal - Saving", message: "I'm saving up for a house", expectedFact: "Is saving for a house"),
        TestCase(name: "Goal - Planning", message: "I'm planning to start a podcast", expectedFact: "Is planning to start a podcast"),

        // === HOBBIES ===
        TestCase(name: "Hobby - Guitar", message: "I play guitar on weekends", expectedFact: "Plays guitar"),
        TestCase(name: "Hobby - Hiking", message: "I love hiking in the mountains", expectedFact: "Loves hiking"),
        TestCase(name: "Hobby - Gaming", message: "I'm really into video games", expectedFact: "Is into video games"),
        TestCase(name: "Hobby - Cooking", message: "I cook a lot at home", expectedFact: "Cooks at home"),
        TestCase(name: "Hobby - Running", message: "I run every morning", expectedFact: "Runs every morning"),
        TestCase(name: "Hobby - Gardening", message: "I spend my weekends gardening", expectedFact: "Does gardening"),
        TestCase(name: "Hobby - Chess", message: "I've been playing chess since childhood", expectedFact: "Plays chess"),

        // === FAMILY/RELATIONSHIPS ===
        TestCase(name: "Family - Kids", message: "I have two kids", expectedFact: "Has two kids"),
        TestCase(name: "Family - Dog", message: "I have a golden retriever named Max", expectedFact: "Has a dog named Max"),
        TestCase(name: "Relationship - Married", message: "I'm married", expectedFact: "Is married"),
        TestCase(name: "Family - Single", message: "I'm single", expectedFact: "Is single"),
        TestCase(name: "Family - Siblings", message: "I have three brothers", expectedFact: "Has three brothers"),
        TestCase(name: "Family - Parent", message: "I'm a new parent", expectedFact: "Is a parent"),
        TestCase(name: "Family - Cat", message: "I have two cats", expectedFact: "Has two cats"),
        TestCase(name: "Family - Partner", message: "My partner works in finance", expectedFact: "Has a partner in finance"),

        // === EDUCATION ===
        TestCase(name: "Education - Degree", message: "I have a degree in biology", expectedFact: "Has a degree in biology"),
        TestCase(name: "Education - PhD", message: "I'm working on my PhD", expectedFact: "Is working on PhD"),
        TestCase(name: "Education - School", message: "I went to MIT", expectedFact: "Went to MIT"),
        TestCase(name: "Education - Major", message: "I majored in economics", expectedFact: "Majored in economics"),
        TestCase(name: "Education - Studying", message: "I'm studying computer science at Stanford", expectedFact: "Studies at Stanford"),

        // === DIETARY ===
        TestCase(name: "Diet - Vegetarian", message: "I'm a vegetarian", expectedFact: "Is vegetarian"),
        TestCase(name: "Diet - Vegan", message: "I've been vegan for 5 years", expectedFact: "Is vegan"),
        TestCase(name: "Diet - Allergy", message: "I'm allergic to shellfish", expectedFact: "Is allergic to shellfish"),
        TestCase(name: "Diet - Intolerant", message: "I'm lactose intolerant", expectedFact: "Is lactose intolerant"),
        TestCase(name: "Diet - Keto", message: "I'm on a keto diet", expectedFact: "Is on keto diet"),
        TestCase(name: "Diet - No meat", message: "I don't eat meat", expectedFact: "Doesn't eat meat"),

        // === SKILLS/LANGUAGES ===
        TestCase(name: "Skill - Language", message: "I speak Spanish fluently", expectedFact: "Speaks Spanish"),
        TestCase(name: "Skill - Bilingual", message: "I'm bilingual in English and French", expectedFact: "Is bilingual"),
        TestCase(name: "Skill - Programming", message: "I know JavaScript and Python", expectedFact: "Knows JavaScript and Python"),
        TestCase(name: "Skill - Certified", message: "I'm a certified accountant", expectedFact: "Is certified accountant"),

        // === LIFESTYLE ===
        TestCase(name: "Lifestyle - Night owl", message: "I'm a night owl", expectedFact: "Is a night owl"),
        TestCase(name: "Lifestyle - Early riser", message: "I'm an early riser", expectedFact: "Is an early riser"),
        TestCase(name: "Lifestyle - Introvert", message: "I'm quite introverted", expectedFact: "Is introverted"),
        TestCase(name: "Lifestyle - No alcohol", message: "I don't drink alcohol", expectedFact: "Doesn't drink alcohol"),
        TestCase(name: "Lifestyle - Exercise", message: "I work out 5 days a week", expectedFact: "Works out regularly"),

        // === INSTRUCTIONS ===
        TestCase(name: "Instruction - Concise", message: "Please keep responses short", expectedFact: "Prefers short responses"),
        TestCase(name: "Instruction - Examples", message: "I prefer code examples over explanations", expectedFact: "Prefers code examples"),
        TestCase(name: "Instruction - Detailed", message: "I like detailed explanations", expectedFact: "Likes detailed explanations"),
        TestCase(name: "Instruction - Step by step", message: "Walk me through things step by step", expectedFact: "Prefers step by step"),
        TestCase(name: "Instruction - No jargon", message: "Please avoid technical jargon", expectedFact: "Prefers no jargon"),
    ]

    // MARK: - Negative Tests (should NOT extract)

    static let negativeTests: [TestCase] = [
        // === QUESTIONS ===
        TestCase(name: "Question - How", message: "How do I fix this bug?", shouldNotExtract: true),
        TestCase(name: "Question - What", message: "What's the best approach?", shouldNotExtract: true),
        TestCase(name: "Question - Why", message: "Why isn't this working?", shouldNotExtract: true),
        TestCase(name: "Question - Can you", message: "Can you help me with this?", shouldNotExtract: true),
        TestCase(name: "Question - Could you", message: "Could you explain that again?", shouldNotExtract: true),
        TestCase(name: "Question - Where", message: "Where should I put this file?", shouldNotExtract: true),
        TestCase(name: "Question - When", message: "When should I use async/await?", shouldNotExtract: true),
        TestCase(name: "Question - Is it", message: "Is this the right way to do it?", shouldNotExtract: true),

        // === REACTIONS/ACKNOWLEDGMENTS ===
        TestCase(name: "Reaction - Thanks", message: "Thanks!", shouldNotExtract: true),
        TestCase(name: "Reaction - Thanks long", message: "Thanks for explaining that", shouldNotExtract: true),
        TestCase(name: "Reaction - Thank you so much", message: "Thank you so much for your help", shouldNotExtract: true),
        TestCase(name: "Acknowledgment - OK", message: "OK", shouldNotExtract: true),
        TestCase(name: "Acknowledgment - Got it", message: "OK, got it", shouldNotExtract: true),
        TestCase(name: "Acknowledgment - Sure", message: "Sure, that works", shouldNotExtract: true),
        TestCase(name: "Acknowledgment - Makes sense", message: "That makes sense", shouldNotExtract: true),
        TestCase(name: "Acknowledgment - I see", message: "I see what you mean", shouldNotExtract: true),
        TestCase(name: "Acknowledgment - Right", message: "Right, I understand", shouldNotExtract: true),
        TestCase(name: "Acknowledgment - Okay", message: "Okay, I'll try that", shouldNotExtract: true),
        TestCase(name: "Acknowledgment - Alright", message: "Alright, let me test it", shouldNotExtract: true),

        // === OPINIONS ABOUT CONVERSATION ===
        TestCase(name: "Opinion - Helpful", message: "That's really helpful", shouldNotExtract: true),
        TestCase(name: "Opinion - Interesting", message: "That's interesting", shouldNotExtract: true),
        TestCase(name: "Opinion - Great", message: "Great explanation", shouldNotExtract: true),
        TestCase(name: "Opinion - Perfect", message: "Perfect, that's exactly what I needed", shouldNotExtract: true),
        TestCase(name: "Opinion - Awesome", message: "This is awesome", shouldNotExtract: true),
        TestCase(name: "Opinion - Good point", message: "Good point, I hadn't considered that", shouldNotExtract: true),
        TestCase(name: "Opinion - Clever", message: "That's a clever solution", shouldNotExtract: true),
        TestCase(name: "Opinion - Clear", message: "That's much clearer now", shouldNotExtract: true),

        // === TEMPORARY STATES ===
        TestCase(name: "Temp - Confused", message: "I'm confused right now", shouldNotExtract: true),
        TestCase(name: "Temp - Thinking", message: "Let me think about this", shouldNotExtract: true),
        TestCase(name: "Temp - Stuck", message: "I'm stuck on this part", shouldNotExtract: true),
        TestCase(name: "Temp - Lost", message: "I'm a bit lost here", shouldNotExtract: true),
        TestCase(name: "Temp - Not sure", message: "I'm not sure I follow", shouldNotExtract: true),
        TestCase(name: "Temp - Still working", message: "I'm still working on it", shouldNotExtract: true),
        TestCase(name: "Temp - Getting there", message: "I'm getting closer to a solution", shouldNotExtract: true),
        TestCase(name: "Temp - Having trouble", message: "I'm having trouble with this", shouldNotExtract: true),

        // === GENERIC STATEMENTS ===
        TestCase(name: "Generic - Try", message: "Let me try that", shouldNotExtract: true),
        TestCase(name: "Generic - Understand", message: "I understand now", shouldNotExtract: true),
        TestCase(name: "Generic - See", message: "I see", shouldNotExtract: true),
        TestCase(name: "Generic - Will do", message: "I'll do that", shouldNotExtract: true),
        TestCase(name: "Generic - Makes sense", message: "Yeah that makes sense", shouldNotExtract: true),
        TestCase(name: "Generic - Agree", message: "I agree with that approach", shouldNotExtract: true),

        // === COMMANDS/REQUESTS ===
        TestCase(name: "Command - Show me", message: "Show me an example", shouldNotExtract: true),
        TestCase(name: "Command - Explain", message: "Explain this function", shouldNotExtract: true),
        TestCase(name: "Command - Help me", message: "Help me debug this", shouldNotExtract: true),
        TestCase(name: "Command - Give me", message: "Give me a moment", shouldNotExtract: true),
        TestCase(name: "Command - Tell me", message: "Tell me more about that", shouldNotExtract: true),

        // === FOLLOW-UPS ===
        TestCase(name: "Follow-up - And then", message: "And then what happens?", shouldNotExtract: true),
        TestCase(name: "Follow-up - Also", message: "Also, one more thing", shouldNotExtract: true),
        TestCase(name: "Follow-up - Wait", message: "Wait, I have a question", shouldNotExtract: true),
        TestCase(name: "Follow-up - Actually", message: "Actually, never mind", shouldNotExtract: true),
        TestCase(name: "Follow-up - One more", message: "One more question", shouldNotExtract: true),
        TestCase(name: "Follow-up - By the way", message: "By the way, quick question", shouldNotExtract: true),

        // === EXPRESSIONS OF EMOTION ===
        TestCase(name: "Emotion - Frustrated", message: "This is frustrating", shouldNotExtract: true),
        TestCase(name: "Emotion - Excited", message: "I'm excited to try this", shouldNotExtract: true),
        TestCase(name: "Emotion - Surprised", message: "Oh wow, I didn't expect that", shouldNotExtract: true),
        TestCase(name: "Emotion - Worried", message: "I'm worried this might break something", shouldNotExtract: true),
        TestCase(name: "Emotion - Happy", message: "I'm happy with this solution", shouldNotExtract: true),

        // === META CONVERSATION ===
        TestCase(name: "Meta - Going back", message: "Going back to what you said earlier", shouldNotExtract: true),
        TestCase(name: "Meta - As I mentioned", message: "As I mentioned before", shouldNotExtract: true),
        TestCase(name: "Meta - To clarify", message: "To clarify what I meant", shouldNotExtract: true),
        TestCase(name: "Meta - In other words", message: "In other words, yes", shouldNotExtract: true),
    ]

    // MARK: - Edge Case Tests

    static let edgeCaseTests: [TestCase] = [
        // === SUBTLE FACTS EMBEDDED IN CONTEXT (should extract) ===
        TestCase(name: "Edge - Subtle preference", message: "Unlike my sister, I prefer tea over coffee", expectedFact: "Prefers tea over coffee"),
        TestCase(name: "Edge - Embedded fact", message: "So anyway, I'm a vegetarian, but that's not relevant here", expectedFact: "Is vegetarian"),
        TestCase(name: "Edge - Dismissive context", message: "This is off topic but I'm allergic to peanuts", expectedFact: "Is allergic to peanuts"),
        TestCase(name: "Edge - Parenthetical", message: "The code works fine (I'm using a Mac by the way)", expectedFact: "Uses a Mac"),
        TestCase(name: "Edge - Casual mention", message: "Oh I forgot to mention I'm left-handed", expectedFact: "Is left-handed"),
        TestCase(name: "Edge - BTW", message: "BTW I'm colorblind so I might miss some UI issues", expectedFact: "Is colorblind"),

        // === PAST TENSE (should extract) ===
        TestCase(name: "Edge - Past job", message: "I used to be a chef", expectedFact: "Was a chef"),
        TestCase(name: "Edge - Past location", message: "I grew up in Chicago", expectedFact: "Grew up in Chicago"),
        TestCase(name: "Edge - Former", message: "I'm a former marine", expectedFact: "Is a former marine"),
        TestCase(name: "Edge - Previously", message: "I previously worked at Amazon", expectedFact: "Previously worked at Amazon"),

        // === COMPOUND STATEMENTS (should extract at least one) ===
        TestCase(name: "Edge - Compound intro", message: "I'm John, a developer from NYC", expectedFact: "Is named John"),
        TestCase(name: "Edge - Multiple facts", message: "I'm Sarah and I work at Google", expectedFact: "Works at Google"),
        TestCase(name: "Edge - With context", message: "As a nurse, I see this all the time", expectedFact: "Is a nurse"),
        TestCase(name: "Edge - Since clause", message: "Since I'm a developer, I understand the technical side", expectedFact: "Is a developer"),

        // === NEGATIONS THAT ARE FACTS (should extract) ===
        TestCase(name: "Edge - Negative preference", message: "I don't eat meat", expectedFact: "Doesn't eat meat"),
        TestCase(name: "Edge - Never", message: "I never drink alcohol", expectedFact: "Doesn't drink alcohol"),
        TestCase(name: "Edge - No longer", message: "I no longer work at that company", expectedFact: "Left previous company"),
        TestCase(name: "Edge - Not anymore", message: "I'm not a smoker anymore", expectedFact: "Quit smoking"),

        // === CONDITIONAL/HABITUAL FACTS (should extract) ===
        TestCase(name: "Edge - Usually", message: "I usually wake up at 6am", expectedFact: "Usually wakes up at 6am"),
        TestCase(name: "Edge - Always", message: "I always drink water in the morning", expectedFact: "Drinks water in morning"),
        TestCase(name: "Edge - Tend to", message: "I tend to prefer dark mode", expectedFact: "Prefers dark mode"),
        TestCase(name: "Edge - Current project", message: "I'm building an iOS app right now", expectedFact: "Is building an iOS app"),

        // === SHOULD NOT EXTRACT - HYPOTHETICALS ===
        TestCase(name: "Edge - Hypothetical if", message: "If I were a developer, I would use Swift", shouldNotExtract: true),
        TestCase(name: "Edge - Hypothetical would", message: "I would love to live in Japan someday", shouldNotExtract: true),
        TestCase(name: "Edge - Hypothetical could", message: "I could see myself doing that", shouldNotExtract: true),
        TestCase(name: "Edge - Hypothetical might", message: "I might switch to Android eventually", shouldNotExtract: true),

        // === SHOULD NOT EXTRACT - QUOTES/THIRD PARTY ===
        TestCase(name: "Edge - Quote friend", message: "My friend said 'I love Python'", shouldNotExtract: true),
        TestCase(name: "Edge - Quote coworker", message: "My coworker mentioned she's a vegetarian", shouldNotExtract: true),
        TestCase(name: "Edge - Someone told me", message: "Someone told me they prefer React", shouldNotExtract: true),
        TestCase(name: "Edge - I heard", message: "I heard that developers like TypeScript", shouldNotExtract: true),

        // === SHOULD NOT EXTRACT - GENERAL STATEMENTS ===
        TestCase(name: "Edge - General people", message: "People usually prefer coffee in the morning", shouldNotExtract: true),
        TestCase(name: "Edge - General everyone", message: "Everyone seems to like this feature", shouldNotExtract: true),
        TestCase(name: "Edge - General most", message: "Most developers use Git", shouldNotExtract: true),
        TestCase(name: "Edge - General usually", message: "Usually this kind of bug is a typo", shouldNotExtract: true),

        // === SHOULD NOT EXTRACT - OPINIONS ABOUT EXTERNAL THINGS ===
        TestCase(name: "Edge - Opinion tech", message: "Python is better than JavaScript", shouldNotExtract: true),
        TestCase(name: "Edge - Opinion product", message: "This app is really well designed", shouldNotExtract: true),
        TestCase(name: "Edge - Opinion code", message: "That function is poorly written", shouldNotExtract: true),

        // === AMBIGUOUS - COULD GO EITHER WAY ===
        TestCase(name: "Edge - Thinking about", message: "I'm thinking about learning Rust", expectedFact: "Is considering learning Rust"),
        TestCase(name: "Edge - Interested in", message: "I'm interested in machine learning", expectedFact: "Is interested in ML"),
        TestCase(name: "Edge - New to", message: "I'm new to iOS development", expectedFact: "Is new to iOS development"),
        TestCase(name: "Edge - Experience with", message: "I have 10 years of experience with Java", expectedFact: "Has 10 years Java experience"),

        // === REAL CONVERSATION PATTERNS ===
        TestCase(name: "Real - Project context", message: "I'm working on this for my startup", expectedFact: "Has a startup"),
        TestCase(name: "Real - Role context", message: "As the lead developer on my team, I need to decide", expectedFact: "Is a lead developer"),
        TestCase(name: "Real - Deadline mention", message: "I need to finish this before my vacation next week", expectedFact: "Has vacation next week"),
        TestCase(name: "Real - Personal constraint", message: "I can only work on this in the evenings because of my day job", expectedFact: "Has a day job"),
    ]
}

#endif
