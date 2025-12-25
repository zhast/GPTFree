//
//  chatApp.swift
//  chat
//
//  Created by Steven Zhang on 11/13/25.
//

import SwiftUI

@main
struct chatApp: App {
    @State private var isRunningTests = false
    @State private var testType = ""

    init() {
        // Check for automated test mode
        if CommandLine.arguments.contains("--run-summary-tests") {
            isRunningTests = true
            testType = "Summary"
            Task {
                await SummaryTestRunner.shared.runAllTests()
                // Give time for file to write
                try? await Task.sleep(for: .seconds(1))
                exit(0)
            }
        } else if CommandLine.arguments.contains("--run-fact-extraction-tests") {
            isRunningTests = true
            testType = "Fact Extraction"
            Task {
                await FactExtractionTestRunner.shared.runAllTests()
                // Give time for file to write
                try? await Task.sleep(for: .seconds(1))
                exit(0)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if isRunningTests {
                VStack {
                    ProgressView()
                    Text("Running \(testType) Tests...")
                        .padding()
                }
            } else {
                MainView()
            }
        }
    }
}
