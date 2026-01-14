//
//  SidebarView.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var conversationStore: ConversationStore
    @EnvironmentObject var memoryStore: MemoryStore
    @State private var showingMemoryView = false

    var body: some View {
        List(selection: $conversationStore.currentConversationId) {
            Section {
                ForEach(conversationStore.conversations) { conversation in
                    ConversationRowView(conversation: conversation)
                        .tag(conversation.id)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await conversationStore.deleteConversation(conversation.id)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text("Chats")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    _ = conversationStore.createNewConversation(isManual: true)
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingMemoryView = true
                } label: {
                    Label("Memory", systemImage: "brain")
                }
            }
        }
        .sheet(isPresented: $showingMemoryView) {
            NavigationStack {
                MemoryView()
                    .environmentObject(memoryStore)
            }
        }
    }
}

struct ConversationRowView: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(.headline)
                .lineLimit(1)

            HStack {
                Text(conversation.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if conversation.messageCount > 0 {
                    Text("\(conversation.messageCount) messages")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if let summary = conversation.summary, !summary.keyTopics.isEmpty {
                HStack(spacing: 4) {
                    ForEach(summary.keyTopics.prefix(2), id: \.self) { topic in
                        Text(topic)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationSplitView {
        SidebarView()
            .environmentObject(ConversationStore())
            .environmentObject(MemoryStore())
    } detail: {
        Text("Detail")
    }
}
