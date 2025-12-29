//
//  MainView.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import SwiftUI

struct MainView: View {
    @StateObject private var conversationStore = ConversationStore()
    @StateObject private var memoryStore = MemoryStore()
    @State private var showingSidebar = false
    @State private var showingMemoryView = false
    @State private var showingDebugView = false
    @State private var previousConversationId: UUID?

    private let sidebarWidth: CGFloat = 300

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Main chat view
                Group {
                    if let conversationId = conversationStore.currentConversationId {
                        ChatView(conversationId: conversationId, showingSidebar: $showingSidebar)
                            .id(conversationId)
                            .environmentObject(conversationStore)
                            .environmentObject(memoryStore)
                    } else {
                        VStack {
                            HStack {
                                if !showingSidebar {
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showingSidebar.toggle()
                                        }
                                    } label: {
                                        Image(systemName: "line.3.horizontal")
                                            .frame(width: 18, height: 27)
                                    }
                                }
                                Spacer()
                            }
                            .padding()

                            Spacer()

                            ContentUnavailableView {
                                Label("No Chat Selected", systemImage: "bubble.left.and.bubble.right")
                            } description: {
                                Text("Tap the menu or swipe to select a chat.")
                            } actions: {
                                Button("New Chat") {
                                    _ = conversationStore.createNewConversation()
                                }
                            }

                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: showingSidebar ? sidebarWidth : 0)

                // Dimmed overlay when sidebar is open
                if showingSidebar {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .offset(x: sidebarWidth)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingSidebar = false
                            }
                        }
                }

                // Sliding sidebar
                SlidingSidebarView(isShowing: $showingSidebar, showingDebugView: $showingDebugView)
                    .environmentObject(conversationStore)
                    .frame(width: sidebarWidth)
                    .offset(x: showingSidebar ? 0 : -sidebarWidth)
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.width > threshold && !showingSidebar {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingSidebar = true
                            }
                        } else if value.translation.width < -threshold && showingSidebar {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingSidebar = false
                            }
                        }
                    }
            )
        }
        .sheet(isPresented: $showingMemoryView) {
            MemoryView()
                .environmentObject(memoryStore)
        }
        #if DEBUG
        .sheet(isPresented: $showingDebugView) {
            DebugView()
                .environmentObject(conversationStore)
        }
        #endif
        .task {
            await conversationStore.load()
            await memoryStore.load()

            // Generate summaries for existing conversations that don't have them
            await generateMissingSummaries()
        }
        .onChange(of: conversationStore.currentConversationId) { oldValue, newValue in
            // Close sidebar when selecting a conversation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingSidebar = false
            }

            // When switching away from a conversation, extract facts and generate summary
            if let oldId = oldValue, oldId != newValue {
                Task {
                    await processConversationOnSwitch(conversationId: oldId)
                }
            }
            previousConversationId = newValue
        }
    }

    /// Generates summaries for conversations that don't have them yet
    private func generateMissingSummaries() async {
        let persistence = PersistenceService.shared

        for conversation in conversationStore.conversations {
            // Skip if already has summary
            guard conversation.summary == nil else { continue }

            // Skip if too few messages
            guard conversation.messageCount >= 4 else { continue }

            do {
                let messages = try await persistence.loadMessages(for: conversation.id)
                guard messages.count >= 4 else { continue }

                print("[MainView] Generating summary for: \(conversation.title)")
                let summary = try await SummaryGenerationService.shared.generateSummary(from: messages)
                await MainActor.run {
                    conversationStore.updateSummary(summary, for: conversation.id)
                }
            } catch {
                print("[MainView] Failed to generate summary for \(conversation.title): \(error)")
            }
        }
    }

    /// Generates summary when leaving a conversation
    private func processConversationOnSwitch(conversationId: UUID) async {
        // Note: Fact extraction is now done in real-time after each message in ChatViewModel
        // Only generate summary here if needed

        guard conversationStore.conversations.first(where: { $0.id == conversationId })?.summary == nil else {
            return
        }

        let persistence = PersistenceService.shared

        do {
            let messages = try await persistence.loadMessages(for: conversationId)

            // Only generate summary if there are enough messages
            guard messages.count >= 4 else { return }

            let summary = try await SummaryGenerationService.shared.generateSummary(from: messages)
            await MainActor.run {
                conversationStore.updateSummary(summary, for: conversationId)
            }
        } catch {
            print("Summary generation failed: \(error)")
        }
    }
}

#Preview {
    MainView()
}
