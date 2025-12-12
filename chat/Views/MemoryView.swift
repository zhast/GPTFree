//
//  MemoryView.swift
//  chat
//
//  Created by Steven Zhang on 12/11/25.
//

import SwiftUI

struct MemoryView: View {
    @EnvironmentObject var memoryStore: MemoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var editingId: UUID?
    @State private var editText: String = ""
    @State private var newMemoryText: String = ""
    @FocusState private var focusedId: UUID?
    @FocusState private var isNewMemoryFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Existing memories
                ForEach(memoryStore.facts) { fact in
                    MemoryRow(
                        fact: fact,
                        isEditing: editingId == fact.id,
                        editText: editingId == fact.id ? $editText : .constant(fact.content),
                        isFocused: focusedId == fact.id,
                        onTap: {
                            startEditing(fact)
                        },
                        onSubmit: {
                            saveEdit(for: fact)
                        },
                        onDelete: {
                            withAnimation {
                                memoryStore.deleteFact(fact.id)
                            }
                        }
                    )
                    .focused($focusedId, equals: fact.id)
                }

                // Add new memory field
                HStack(spacing: 12) {
                    TextField("Add a memory...", text: $newMemoryText)
                        .textFieldStyle(.plain)
                        .focused($isNewMemoryFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addNewMemory()
                        }

                    if !newMemoryText.isEmpty {
                        Button {
                            addNewMemory()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissKeyboard()
                }
            }
        }
        .navigationTitle("Memories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onChange(of: focusedId) { oldValue, newValue in
            // Save when focus leaves an editing field
            if let oldId = oldValue, editingId == oldId, newValue != oldId {
                if let fact = memoryStore.facts.first(where: { $0.id == oldId }) {
                    saveEdit(for: fact)
                }
            }
        }
    }

    private func startEditing(_ fact: UserFact) {
        editingId = fact.id
        editText = fact.content
        focusedId = fact.id
    }

    private func saveEdit(for fact: UserFact) {
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != fact.content {
            memoryStore.updateFact(fact.id, content: trimmed)
        }
        editingId = nil
    }

    private func addNewMemory() {
        let trimmed = newMemoryText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let fact = UserFact(
            category: .context,
            content: trimmed,
            confidence: 1.0,
            source: .userCreated,
            isUserVerified: true
        )
        memoryStore.addFact(fact)
        newMemoryText = ""
    }

    private func dismissKeyboard() {
        // Save any pending edits
        if let id = editingId, let fact = memoryStore.facts.first(where: { $0.id == id }) {
            saveEdit(for: fact)
        }
        focusedId = nil
        isNewMemoryFocused = false
    }
}

struct MemoryRow: View {
    let fact: UserFact
    let isEditing: Bool
    @Binding var editText: String
    let isFocused: Bool
    let onTap: () -> Void
    let onSubmit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill")
                .foregroundStyle(.secondary.opacity(0.5))
                .font(.system(size: 8))

            if isEditing {
                TextField("Memory", text: $editText)
                    .textFieldStyle(.plain)
                    .onSubmit(onSubmit)
            } else {
                Text(fact.content)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
            }
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    NavigationStack {
        MemoryView()
            .environmentObject(MemoryStore())
    }
}
