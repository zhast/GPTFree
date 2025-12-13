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

    init() {
        // Check for automated test mode
        if CommandLine.arguments.contains("--run-summary-tests") {
            isRunningTests = true
            Task {
                await SummaryTestRunner.shared.runAllTests()
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
                    Text("Running Summary Tests...")
                        .padding()
                }
            } else {
                MainView()
            }
        }
    }
}
