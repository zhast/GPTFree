//
//  RecentChatsSummaryView.swift
//  chat
//
//  Displays summaries of recent conversations used in context
//

import SwiftUI

struct RecentChatsSummaryView: View {
    @EnvironmentObject var conversationStore: ConversationStore
    @Environment(\.dismiss) private var dismiss

    private var conversationsWithSummaries: [Conversation] {
        conversationStore.recentConversations
            .filter { $0.summary != nil }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        List {
            if conversationsWithSummaries.isEmpty {
                ContentUnavailableView {
                    Label("No Summaries Yet", systemImage: "text.bubble")
                } description: {
                    Text("Summaries are generated when you switch between conversations with 4+ messages.")
                }
            } else {
                Section {
                    ForEach(conversationsWithSummaries) { conversation in
                        if let summary = conversation.summary {
                            SummaryCard(conversation: conversation, summary: summary)
                        }
                    }
                } header: {
                    Text("Used in Context")
                } footer: {
                    Text("These summaries help the assistant remember your recent conversations.")
                }
            }
        }
        .navigationTitle("Recent Chats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct SummaryCard: View {
    let conversation: Conversation
    let summary: ConversationSummary

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack {
                Text(summary.generatedTitle)
                    .font(.headline)
                Spacer()
                Text("\(summary.messageCount) msgs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Summary text
            Text(summary.summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Topics
            if !summary.keyTopics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(summary.keyTopics, id: \.self) { topic in
                            Text(topic)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Expandable details
            if isExpanded {
                Divider()

                // Participants
                if !summary.participants.isEmpty {
                    HStack {
                        Text("Participants:")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(summary.participants.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // User snippets
                if !summary.userMessageSnippets.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("User asked about:")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        ForEach(summary.userMessageSnippets, id: \.self) { snippet in
                            Text("• \(snippet)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Chunk summaries (if chunked)
                if let chunks = summary.chunkSummaries, !chunks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chunk summaries (\(chunks.count)):")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                            Text("\(index + 1). \(chunk)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Generated timestamp
                Text("Generated \(summary.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Expand/collapse button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(isExpanded ? "Show Less" : "Show More")
                        .font(.caption)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        RecentChatsSummaryView()
            .environmentObject(ConversationStore())
    }
}
