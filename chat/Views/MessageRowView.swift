//
//  MessageRowView.swift
//  chat
//
//  Created by Steven Zhang on 11/13/25.
//

import SwiftUI

struct MessageRowView: View {

    let message: MessageItem
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    private let bubbleShape = RoundedRectangle(cornerRadius: 16)

    var body: some View {
        HStack {
            if message.fromUser { Spacer(minLength: 60) }

            bubbleContent
                .contentShape(.contextMenuPreview, bubbleShape)
                .contextMenu {
                    if message.fromUser {
                        Button {
                            onEdit?()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }

                    Button {
                        UIPasteboard.general.string = message.text
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

            if !message.fromUser { Spacer(minLength: 60) }
        }
    }

    private var bubbleContent: some View {
        Text(markdownText)
            .padding(10)
            .background(bubbleShape.foregroundStyle(message.fromUser ? .blue.opacity(0.4) : Color(.systemGray6)))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    private var markdownText: AttributedString {
        // Try to parse as markdown, fallback to plain text
        do {
            return try AttributedString(markdown: message.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch {
            return AttributedString(message.text)
        }
    }
}
