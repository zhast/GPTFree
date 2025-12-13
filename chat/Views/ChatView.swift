//
//  ChatView.swift
//  chat
//
//  Created by Steven Zhang on 11/13/25.
//

import SwiftUI

struct ChatView: View {
    let conversationId: UUID
    @Binding var showingSidebar: Bool

    @EnvironmentObject var conversationStore: ConversationStore
    @EnvironmentObject var memoryStore: MemoryStore

    @StateObject private var vm: ChatViewModel

    @State private var newMessage: String = ""
    @State private var messageToEdit: MessageItem?
    @State private var editText: String = ""
    @State private var showingContextUsage: Bool = false
    @FocusState private var isInputFocused: Bool

    init(conversationId: UUID, showingSidebar: Binding<Bool>) {
        self.conversationId = conversationId
        self._showingSidebar = showingSidebar
        _vm = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        ForEach(vm.messages) { message in
                            MessageRowView(
                                message: message,
                                onEdit: {
                                    editText = message.text
                                    messageToEdit = message
                                },
                                onDelete: {
                                    vm.deleteMessage(message)
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .onChange(of: vm.messages.count) {
                    if let lastMessage = vm.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isInputFocused) { _, focused in
                    if focused, let lastMessage = vm.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    // Memory update notification
                    if let memoryMessage = vm.memoryUpdateMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "brain")
                                .font(.caption)
                            Text(memoryMessage)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    HStack {
                        TextField("Message", text: $newMessage)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassEffect(.regular, in: .capsule)
                            .lineLimit(1...5)
                            .focused($isInputFocused)

                        Button {
                            let text = newMessage
                            newMessage = ""

                            Task {
                                await vm.sendMessage(
                                    text,
                                    conversationStore: conversationStore,
                                    memoryStore: memoryStore
                                )
                            }
                        } label: {
                            Image(systemName: "arrow.up")
                                .frame(width: 18, height: 27)
                        }
                        .disabled(newMessage.isEmpty || vm.isResponding)
                        .buttonStyle(.glassProminent)
                        .tint(newMessage.isEmpty || vm.isResponding ? .gray : .blue)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .animation(.easeInOut(duration: 0.3), value: vm.memoryUpdateMessage)
            }
            .navigationTitle(conversationStore.currentConversation?.title ?? "Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !showingSidebar {
                        Button {
                            showingContextUsage = true
                        } label: {
                            Image(systemName: "brain")
                                .frame(width: 18, height: 27)
                        }
                    }
                }
            }
        }
        .task {
            await vm.loadMessages()
        }
        .onChange(of: showingSidebar) { _, isShowing in
            if isShowing {
                isInputFocused = false
            }
        }
        .sheet(item: $messageToEdit) { message in
            EditMessageView(
                text: $editText,
                onSave: {
                    vm.updateMessage(message, newText: editText, conversationStore: conversationStore, memoryStore: memoryStore)
                    messageToEdit = nil
                },
                onCancel: {
                    messageToEdit = nil
                }
            )
        }
        .sheet(isPresented: $showingContextUsage) {
            ContextUsageView(messages: vm.messages)
                .environmentObject(conversationStore)
                .environmentObject(memoryStore)
        }
    }
}

struct EditMessageView: View {
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Message", text: $text, axis: .vertical)
                    .lineLimit(3...10)
            }
            .navigationTitle("Edit Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ChatView(conversationId: UUID(), showingSidebar: .constant(false))
        .environmentObject(ConversationStore())
        .environmentObject(MemoryStore())
}
