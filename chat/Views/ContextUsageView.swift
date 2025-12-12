//
//  ContextUsageView.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import SwiftUI

struct ContextUsageView: View {
    @EnvironmentObject var conversationStore: ConversationStore
    @EnvironmentObject var memoryStore: MemoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingInfo = false
    @State private var showingMemoryView = false

    let messages: [MessageItem]

    // Token budget
    // Apple's on-device model has 4096 total tokens (input + output combined)
    private let totalBudget: Double = 4096
    private let reservedForOutput: Double = 1000
    private var inputBudget: Double { totalBudget - reservedForOutput }
    private let charsPerToken: Double = 4

    private func estimateTokens(_ text: String) -> Double {
        Double(text.count) / charsPerToken
    }

    // System instructions (must match ChatViewModel)
    private var systemInstructionsText: String {
        """
        You are a helpful, friendly assistant with memory of past conversations.

        Guidelines:
        - ALWAYS respond to the LAST user message in the conversation.
        - Be concise and conversational. No markdown formatting, bullet points, or headers.
        - Use the User Memory and Recent Conversations context to personalize responses.
        - Reference remembered facts naturally when relevant, but don't force them into every response.
        - Never say "would you like me to", "shall I", "let me know if you want me to" - just do it or answer directly.
        - Keep responses brief unless the user asks for detail.
        """
    }

    private var systemInstructionsTokens: Double {
        estimateTokens(systemInstructionsText)
    }

    private var sessionMetadataText: String {
        """
        [Session Info]
        Date: \(Date().formatted(date: .long, time: .shortened))
        Conversation: \(conversationStore.currentConversation?.title ?? "New Chat")
        """
    }

    private var sessionMetadataTokens: Double {
        estimateTokens(sessionMetadataText)
    }

    private var memoryText: String {
        guard !memoryStore.facts.isEmpty else { return "" }
        var text = "[User Memory]\n"
        for fact in memoryStore.facts.prefix(15) {
            text += "- \(fact.category.rawValue): \(fact.content)\n"
        }
        return text
    }

    private var memoryTokens: Double {
        estimateTokens(memoryText)
    }

    private var recentConversationsText: String {
        let conversationsWithSummaries = conversationStore.recentConversations.filter { $0.summary != nil }
        guard !conversationsWithSummaries.isEmpty else { return "" }
        var text = "[Recent Conversations]\n"
        for conv in conversationsWithSummaries.prefix(5) {
            if let summary = conv.summary {
                text += "- \"\(summary.generatedTitle)\": \(summary.summaryText)\n"
            }
        }
        return text
    }

    private var recentConversationsTokens: Double {
        estimateTokens(recentConversationsText)
    }

    // Calculate how many messages fit in remaining budget
    private var currentMessagesInContext: Int {
        let remainingBudget = inputBudget - systemInstructionsTokens - sessionMetadataTokens - memoryTokens - recentConversationsTokens
        var usedTokens: Double = estimateTokens("[Current Conversation]\n")
        var count = 0

        for message in messages.reversed() {
            let sender = message.fromUser ? "User" : "Assistant"
            let messageText = "\(sender): \(message.text)\n"
            let tokenCount = estimateTokens(messageText)

            if usedTokens + tokenCount <= remainingBudget {
                usedTokens += tokenCount
                count += 1
            } else {
                break
            }
        }
        return count
    }

    private var currentMessagesTokens: Double {
        let remainingBudget = inputBudget - systemInstructionsTokens - sessionMetadataTokens - memoryTokens - recentConversationsTokens
        var usedTokens: Double = estimateTokens("[Current Conversation]\n")

        for message in messages.reversed() {
            let sender = message.fromUser ? "User" : "Assistant"
            let messageText = "\(sender): \(message.text)\n"
            let tokenCount = estimateTokens(messageText)

            if usedTokens + tokenCount <= remainingBudget {
                usedTokens += tokenCount
            } else {
                break
            }
        }
        return usedTokens
    }

    private var inputUsed: Double {
        systemInstructionsTokens + sessionMetadataTokens + memoryTokens + recentConversationsTokens + currentMessagesTokens
    }

    private var totalUsed: Double {
        inputUsed + reservedForOutput
    }

    private var availableInput: Double {
        max(inputBudget - inputUsed, 0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Storage-style bar
                VStack(alignment: .leading, spacing: 8) {
                    // Segmented bar
                    GeometryReader { geometry in
                        HStack(spacing: 1) {
                            // System Instructions
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: barWidth(for: systemInstructionsTokens, in: geometry.size.width))

                            // Session Metadata
                            Rectangle()
                                .fill(Color.orange)
                                .frame(width: barWidth(for: sessionMetadataTokens, in: geometry.size.width))

                            // User Memory
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(width: barWidth(for: memoryTokens, in: geometry.size.width))

                            // Recent Conversations
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: barWidth(for: recentConversationsTokens, in: geometry.size.width))

                            // Current Messages
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: barWidth(for: currentMessagesTokens, in: geometry.size.width))

                            // Available for input
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(width: barWidth(for: availableInput, in: geometry.size.width))

                            // Reserved for output
                            Rectangle()
                                .fill(Color(.systemGray3))
                                .frame(width: barWidth(for: reservedForOutput, in: geometry.size.width))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .frame(height: 20)

                    // Usage text
                    Text("\(Int(inputUsed)) of \(Int(inputBudget)) input tokens used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Legend
                VStack(spacing: 12) {
                    LegendRow(
                        color: .red,
                        title: "System Prompt",
                        detail: "~\(Int(systemInstructionsTokens)) tokens",
                        subtitle: "Assistant behavior guidelines"
                    )

                    LegendRow(
                        color: .orange,
                        title: "Session Info",
                        detail: "~\(Int(sessionMetadataTokens)) tokens",
                        subtitle: "Date, conversation title"
                    )

                    Button {
                        showingMemoryView = true
                    } label: {
                        HStack {
                            LegendRow(
                                color: .yellow,
                                title: "User Memory",
                                detail: "~\(Int(memoryTokens)) tokens",
                                subtitle: "\(min(memoryStore.facts.count, 15)) facts"
                            )
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    LegendRow(
                        color: .green,
                        title: "Recent Chats",
                        detail: "~\(Int(recentConversationsTokens)) tokens",
                        subtitle: "\(conversationStore.recentConversations.filter { $0.summary != nil }.prefix(5).count) summaries"
                    )

                    LegendRow(
                        color: .blue,
                        title: "Current Chat",
                        detail: "~\(Int(currentMessagesTokens)) tokens",
                        subtitle: "\(currentMessagesInContext) of \(messages.count) messages"
                    )

                    LegendRow(
                        color: Color(.systemGray5),
                        title: "Available",
                        detail: "~\(Int(availableInput)) tokens",
                        subtitle: nil
                    )

                    LegendRow(
                        color: Color(.systemGray3),
                        title: "Reserved for Response",
                        detail: "~\(Int(reservedForOutput)) tokens",
                        subtitle: "Model output"
                    )
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("About Context", isPresented: $showingInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Context is what the AI remembers during your conversation. When it fills up, older messages are forgotten.")
            }
            .sheet(isPresented: $showingMemoryView) {
                NavigationStack {
                    MemoryView()
                        .environmentObject(memoryStore)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func barWidth(for tokens: Double, in totalWidth: CGFloat) -> CGFloat {
        let percentage = tokens / totalBudget
        return max(CGFloat(percentage) * totalWidth, tokens > 0 ? 2 : 0)
    }
}

struct LegendRow: View {
    let color: Color
    let title: String
    let detail: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContextUsageView(messages: [])
        .environmentObject(ConversationStore())
        .environmentObject(MemoryStore())
}
