//
//  VorliChatView.swift
//  Receipt Tracker
//
//  Full-screen Vorli AI chat interface.
//

import SwiftUI
import SwiftData

// MARK: - Main Chat View

struct VorliChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Receipt.timestamp, order: .reverse) private var allReceipts: [Receipt]

    @State private var viewModel: VorliChatViewModel?
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat messages area
                if let vm = viewModel {
                    ChatMessagesView(
                        messages: vm.messages,
                        isStreaming: vm.isStreaming
                    )
                } else {
                    Spacer()
                }

                // Quick prompts — shown when no messages yet
                if viewModel?.messages.isEmpty == true {
                    QuickPromptsRow { prompt in
                        viewModel?.sendQuickPrompt(prompt)
                    }
                    .padding(.bottom, 8)
                }

                // Input bar
                ChatInputBar(
                    text: $inputText,
                    isFocused: $inputFocused,
                    isStreaming: viewModel?.isStreaming ?? false
                ) {
                    submitInput()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VorliHeaderTitle()
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .alert("Greška", isPresented: Binding(
                get: { viewModel?.showError ?? false },
                set: { viewModel?.showError = $0 }
            )) {
                Button("U redu", role: .cancel) {}
            } message: {
                Text(viewModel?.errorMessage ?? "")
            }
        }
        .task {
            viewModel = VorliChatViewModel(allReceipts: allReceipts)
        }
    }

    private func submitInput() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        inputFocused = false
        viewModel?.send(text)
    }
}

// MARK: - Header Title

private struct VorliHeaderTitle: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Vorli")
                .font(.system(.headline, design: .monospaced, weight: .medium))
        }
    }
}

// MARK: - Chat Messages

private struct ChatMessagesView: View {
    let messages: [VorliMessage]
    let isStreaming: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(messages) { message in
                        if message.role == .user {
                            UserMessageBubble(text: message.content)
                                .id(message.id)
                        } else {
                            AIResponseView(text: message.content, isStreaming: isStreaming && message == messages.last)
                                .id(message.id)
                        }
                    }

                    // Streaming indicator — when last message is empty and streaming
                    if isStreaming, let last = messages.last, last.role == .assistant, last.content.isEmpty {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    if let lastId = messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: messages.last?.content) { _, _ in
                if let lastId = messages.last?.id {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - User Message Bubble

struct UserMessageBubble: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: 60)
            Text(text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemFill))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - AI Response View (no bubble)

struct AIResponseView: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if text.isEmpty && isStreaming {
                    TypingIndicator()
                } else {
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 40)
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundStyle(.secondary)
                    .scaleEffect(phase == i ? 1.3 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { phase = 1 }
    }
}

// MARK: - Quick Prompts Row

struct QuickPromptsRow: View {
    let onSelect: (QuickPrompt) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(QuickPrompt.all) { prompt in
                    QuickPromptCard(prompt: prompt) {
                        onSelect(prompt)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Quick Prompt Card

struct QuickPromptCard: View {
    let prompt: QuickPrompt
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: prompt.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.title)
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(prompt.subtitle)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: 140, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let isStreaming: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Pitaj Vorlija...", text: $text, axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1...5)
                .focused(isFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit {
                    onSend()
                }

            Button(action: onSend) {
                Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? .primary : .tertiary)
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.15), value: canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && !isStreaming
    }
}

// MARK: - Preview

#Preview {
    VorliChatView()
        .modelContainer(for: [Receipt.self, Budget.self, BudgetEntry.self], inMemory: true)
}
