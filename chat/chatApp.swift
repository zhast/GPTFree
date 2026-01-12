//
//  chatApp.swift
//  chat
//
//  Created by Steven Zhang on 11/13/25.
//

import SwiftUI

@main
struct chatApp: App {
    #if DEBUG
    @State private var isRunningTests = false
    @State private var testType = ""
    #endif

    init() {
        #if DEBUG
        // Check for automated test mode (DEBUG only)
        if CommandLine.arguments.contains("--run-summary-tests") {
            _isRunningTests = State(initialValue: true)
            _testType = State(initialValue: "Summary")
            Task {
                await SummaryTestRunner.shared.runAllTests()
                try? await Task.sleep(for: .seconds(1))
                exit(0)
            }
        } else if CommandLine.arguments.contains("--run-fact-extraction-tests") {
            _isRunningTests = State(initialValue: true)
            _testType = State(initialValue: "Fact Extraction")
            Task {
                await FactExtractionTestRunner.shared.runAllTests()
                try? await Task.sleep(for: .seconds(1))
                exit(0)
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if isRunningTests {
                VStack {
                    ProgressView()
                    Text("Running \(testType) Tests...")
                        .padding()
                }
            } else {
                GenerativeAvailabilityGateView {
                    MainView()
                }
            }
            #else
            GenerativeAvailabilityGateView {
                MainView()
            }
            #endif
        }
    }
}
