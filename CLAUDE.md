# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS chat application built with SwiftUI and the MVVM architecture pattern. The app provides a chat interface with AI responses using Apple's FoundationModels framework (on-device LLM). It features a **4-layer context management system** inspired by [ChatGPT's memory architecture](https://manthan.bearblog.dev/i-reverse-engineered-chatgpts-memory-system/).

## Build Commands

```bash
# Build Debug configuration
xcodebuild -project chat.xcodeproj -scheme chat -configuration Debug

# Build Release configuration
xcodebuild -project chat.xcodeproj -scheme chat -configuration Release

# Clean build artifacts
xcodebuild -project chat.xcodeproj -scheme chat clean

# Open in Xcode (recommended for development)
open chat.xcodeproj
```

## 4-Layer Context Architecture

The app assembles context for each LLM request using four layers, similar to ChatGPT:

### Layer 1: Session Metadata (Ephemeral)
- Current date/time
- Conversation title
- *Simplified from ChatGPT which includes device info, usage patterns, etc.*

### Layer 2: User Memory (Long-term Facts)
- Persistent facts about the user (name, preferences, goals, etc.)
- Auto-extracted from conversations via on-device LLM
- Can be manually added/edited/deleted by user
- Categories: personalInfo, preferences, goals, context, instructions
- Limited to 15 facts per context

### Layer 3: Recent Conversations Summary
- Lightweight summaries of past conversations
- Generated via on-device LLM when switching away from a conversation
- Includes: generated title + summary text
- Limited to 5 most recent summaries
- *ChatGPT uses timestamp + title + user message snippets only*

### Layer 4: Current Session Messages (Sliding Window)
- **Token-based** sliding window (not message-count based)
- Fills remaining token budget with most recent messages
- Older messages "roll off" when budget is exhausted
- Full message text preserved (not summarized)

### Token Budget

Apple's on-device model has a **4096 token combined limit** (input + output):
- **Reserved for output**: ~1000 tokens
- **Input budget**: ~3096 tokens for all 4 layers
- Token estimation: ~4 characters per token

## File Structure

```
chat/
├── chatApp.swift                      # App entry point
├── Models/
│   ├── MessageItem.swift              # Message with conversationId, timestamp
│   ├── Conversation.swift             # Conversation metadata + summary
│   ├── UserFact.swift                 # Long-term memory facts
│   └── ConversationSummary.swift      # LLM-generated summary
├── Services/
│   ├── PersistenceService.swift       # Thread-safe file I/O (actor)
│   ├── FactExtractionService.swift    # Auto-extracts facts via LLM
│   └── SummaryGenerationService.swift # Generates chat summaries via LLM
├── Stores/
│   ├── ConversationStore.swift        # Manages multiple conversations
│   └── MemoryStore.swift              # Manages user facts
├── ViewModels/
│   └── ChatViewModel.swift            # Chat logic + context assembly
└── Views/
    ├── MainView.swift                 # Root view with sliding sidebar
    ├── SlidingSidebarView.swift       # Conversation list
    ├── ChatView.swift                 # Main chat interface
    ├── MessageRowView.swift           # Message bubbles with context menu
    ├── ContextUsageView.swift         # Token usage visualization
    └── MemoryView.swift               # Fact management UI
```

## Storage Structure

```
~/Documents/
├── conversations_index.json    # Conversation list with summaries
├── user_memory.json            # User facts
└── conversations/
    ├── {uuid1}.json            # Messages for conversation 1
    └── {uuid2}.json            # Messages for conversation 2
```

## Key Technical Details

- **iOS Deployment Target**: 26.1
- **Bundle ID**: `com.bignumbers.chat`
- **Dependencies**: SwiftUI, Combine, FoundationModels framework
- **Data Persistence**: JSON serialization to Documents folder
- **Concurrency**: Swift async/await with MainActor isolation
- **Thread Safety**: PersistenceService uses Swift actor for file I/O

## Context Assembly Flow

```
User sends message
    ↓
ChatViewModel.assembleContext()
    ↓
┌─────────────────────────────────────┐
│ [Session Info]                      │ ← Layer 1: ~25 tokens
│ Date, conversation title            │
├─────────────────────────────────────┤
│ [User Memory]                       │ ← Layer 2: variable
│ - preferences: Likes concise code   │
│ - goals: Learning SwiftUI           │
├─────────────────────────────────────┤
│ [Recent Conversations]              │ ← Layer 3: variable
│ - "SwiftUI Navigation": Discussed   │
│   NavigationStack patterns...       │
├─────────────────────────────────────┤
│ [Current Conversation]              │ ← Layer 4: fills remaining budget
│ User: How do I add a sidebar?       │
│ Assistant: You can use...           │
│ User: Can you show an example?      │
└─────────────────────────────────────┘
    ↓
LanguageModelSession.respond(to: assembledContext)
    ↓
Response displayed + saved
```

## Differences from ChatGPT

| Layer | ChatGPT | This App |
|-------|---------|----------|
| Session Metadata | Device, browser, location, usage patterns, screen size | Date + conversation title only |
| User Memory | Same concept | Same - auto-extracted + manual |
| Recent Conversations | Timestamp + title + user snippets (~15) | Title + LLM summary (5 max) |
| Current Messages | Token-based sliding window | Same |
| Token Limit | ~128K (cloud) | 4096 (on-device) |
