//
//  VorliChatView.swift
//  Receipt Tracker
//
//  Full-screen Vorli AI chat interface.
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Main Chat View

struct VorliChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Receipt.timestamp, order: .reverse) private var allReceipts: [Receipt]
    @Query private var budgetEntries: [BudgetEntry]
    @Query private var fixedCosts: [FixedCost]
    @Query private var wishes: [Wish]

    @State private var viewModel: VorliChatViewModel?
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool
    @State private var showAddMenu = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var navigateToHistory = false

    var body: some View {
        NavigationStack {
            Group {
                // Chat messages area
                if let vm = viewModel {
                    ChatMessagesView(
                        messages: vm.messages,
                        isStreaming: vm.isStreaming
                    )
                } else {
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VorliHeaderTitle(title: viewModel?.conversationTitle ?? "Vorli")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        viewModel?.saveCurrentSessionIfNeeded()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    // Chat History
                    Button {
                        navigateToHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .medium))
                    }
                    // New Chat
                    Button {
                        viewModel?.startNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToHistory) {
                ChatHistoryView { session in
                    viewModel?.load(session: session)
                    navigateToHistory = false
                }
            }
            // safeAreaInset je jedini ispravni iOS pattern za chat input bar sa TextField-om.
            // ToolbarItemGroup(.bottomBar) ne podržava full-width TextField — duplicira sadržaj.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if viewModel?.messages.isEmpty == true {
                        QuickPromptsRow { prompt in
                            viewModel?.sendQuickPrompt(prompt, wishes: wishes)
                        }
                        .padding(.bottom, 4)
                    }
                    ChatInputBar(
                        inputText: $inputText,
                        inputFocused: $inputFocused,
                        showAddMenu: $showAddMenu,
                        hasContent: hasContent,
                        isStreaming: viewModel?.isStreaming == true,
                        onSubmit: submitInput,
                        onCamera: { showCamera = true },
                        onPhotos: { showPhotoPicker = true }
                    )
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView { image in
                    // Future: send image to Vorli for OCR analysis
                    showCamera = false
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
            viewModel = VorliChatViewModel(
                allReceipts: allReceipts,
                stanje: FinanceCalculator.totalLeftover(receipts: allReceipts, entries: budgetEntries, fixed: fixedCosts)
            )
        }
    }

    private var hasContent: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submitInput() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        inputFocused = false
        viewModel?.send(text, wishes: wishes)
    }
}

// MARK: - Chat Input Bar

private struct ChatInputBar: View {
    @Binding var inputText: String
    var inputFocused: FocusState<Bool>.Binding
    @Binding var showAddMenu: Bool
    let hasContent: Bool
    let isStreaming: Bool
    let onSubmit: () -> Void
    let onCamera: () -> Void
    let onPhotos: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Add button — Liquid Glass, no explicit size so system matches toolbar button sizing
            Button {
                showAddMenu = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17))
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .confirmationDialog("Dodaj sliku", isPresented: $showAddMenu) {
                Button("Fotografiši") { onCamera() }
                Button("Odaberi iz galerije") { onPhotos() }
                Button("Otkaži", role: .cancel) {}
            }

            // Text field — Liquid Glass capsule, minHeight matches .glass button height (44pt)
            TextField("Pitaj Vorlija...", text: $inputText, axis: .vertical)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(1...4)
                .focused(inputFocused)
                .onSubmit { onSubmit() }
                .padding(.horizontal, 14)
                .padding(.trailing, hasContent ? 28 : 14)
                .frame(maxWidth: .infinity, minHeight: 44)
                .glassEffect(.regular.interactive(), in: .capsule)
                .overlay(alignment: .trailing) {
                    if hasContent {
                        Button(action: onSubmit) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 22))
                        }
                        .padding(.trailing, 6)
                        .transition(.scale.combined(with: .opacity))
                        .disabled(isStreaming)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: hasContent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Header Title

private struct VorliHeaderTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.footnote, design: .monospaced, weight: .regular))
            .lineLimit(1)
            .truncationMode(.tail)
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
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        if message.role == .user {
                            UserMessageBubble(text: message.textContent)
                                .id(message.id)
                        } else {
                            switch message.content {
                            case .text(let t):
                                AIResponseView(text: t, isStreaming: isStreaming && message == messages.last)
                                    .id(message.id)
                            case .card(let payload):
                                let reportText = index > 0 ? messages[index - 1].textContent : ""
                                HStack(alignment: .top) {
                                    ActionItemCardView(payload: payload, reportText: reportText)
                                    Spacer(minLength: 40)
                                }
                                .id(message.id)
                            }
                        }
                    }

                    // Streaming indicator — when last message is empty and streaming
                    if isStreaming, let last = messages.last, last.role == .assistant, last.textContent.isEmpty {
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
            .onChange(of: messages.last?.textContent) { _, _ in
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
                .font(.system(.subheadline, design: .monospaced))
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
                    MarkdownTextView(text: text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 40)
        }
    }
}

// MARK: - Markdown Text View
//
// Renders AI response text with proper Markdown formatting.
// Uses a custom block parser because SwiftUI Text only supports inline Markdown —
// block-level elements (headings, lists, code blocks) require manual parsing.

private struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks(text).enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let content):
            Text(inlineAttributed(content))
                .font(headingFont(level))
                .foregroundStyle(.primary)
                .padding(.top, level == 1 ? 4 : 2)

        case .bulletItem(let content):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(inlineAttributed(content))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.primary)
            }

        case .numberedItem(let number, let content):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 20, alignment: .trailing)
                Text(inlineAttributed(content))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.primary)
            }

        case .codeBlock(let code):
            Text(code)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 8))

        case .paragraph(let content):
            Text(inlineAttributed(content))
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(.headline, design: .monospaced, weight: .bold)
        case 2: return .system(.subheadline, design: .monospaced, weight: .semibold)
        default: return .system(.footnote, design: .monospaced, weight: .semibold)
        }
    }

    // Parses inline Markdown (**bold**, *italic*, `code`) into AttributedString
    private func inlineAttributed(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

// MARK: - Markdown Block Types

private enum MarkdownBlock {
    case heading(level: Int, content: String)
    case bulletItem(content: String)
    case numberedItem(number: Int, content: String)
    case codeBlock(code: String)
    case paragraph(content: String)
}

private func parseBlocks(_ text: String) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    let lines = text.components(separatedBy: "\n")
    var i = 0

    while i < lines.count {
        let line = lines[i]

        // Code block fence
        if line.hasPrefix("```") {
            var codeLines: [String] = []
            i += 1
            while i < lines.count && !lines[i].hasPrefix("```") {
                codeLines.append(lines[i])
                i += 1
            }
            blocks.append(.codeBlock(code: codeLines.joined(separator: "\n")))
            i += 1
            continue
        }

        // Heading
        if line.hasPrefix("#") {
            let level = line.prefix(while: { $0 == "#" }).count
            let content = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
            blocks.append(.heading(level: min(level, 3), content: content))
            i += 1
            continue
        }

        // Bullet list item
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            let content = String(line.dropFirst(2))
            blocks.append(.bulletItem(content: content))
            i += 1
            continue
        }

        // Numbered list item
        let numberedPattern = /^(\d+)\.\s(.+)/
        if let match = line.firstMatch(of: numberedPattern) {
            let number = Int(match.1) ?? 1
            let content = String(match.2)
            blocks.append(.numberedItem(number: number, content: content))
            i += 1
            continue
        }

        // Empty line — skip
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            i += 1
            continue
        }

        // Paragraph — merge consecutive non-special lines
        var paragraphLines: [String] = [line]
        i += 1
        while i < lines.count {
            let next = lines[i]
            if next.trimmingCharacters(in: .whitespaces).isEmpty
                || next.hasPrefix("#")
                || next.hasPrefix("- ")
                || next.hasPrefix("* ")
                || next.hasPrefix("```")
                || next.firstMatch(of: /^\d+\.\s/) != nil {
                break
            }
            paragraphLines.append(next)
            i += 1
        }
        blocks.append(.paragraph(content: paragraphLines.joined(separator: " ")))
    }

    return blocks
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
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.title)
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(prompt.subtitle)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: 140, alignment: .leading)
            .glassEffect(in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Camera Picker (UIImagePickerController wrapper)

struct CameraPickerView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Chat History Sheet

// MARK: - Chat History Card

struct ChatHistoryCardView: View {
    let session: VorliChatSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 16) {
                Text(session.title)
                    .font(.system(.subheadline, design: .monospaced, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Text(session.date, style: .date)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.04), radius: 1.5, x: 0, y: 1)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.03), radius: 3, x: 0, y: 6)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.02), radius: 4, x: 0, y: 13)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.01), radius: 4.5, x: 0, y: 24)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0), radius: 5, x: 0, y: 37)
    }
}

// MARK: - Chat History View

struct ChatHistoryView: View {
    let onSelect: (VorliChatSession) -> Void

    @State private var sessions: [VorliChatSession] = []

    var body: some View {
        Group {
            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("Nema istorije")
                        .font(.system(.headline, design: .monospaced, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("Prethodni razgovori će se ovde pojaviti.")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(sessions) { session in
                            Button {
                                onSelect(session)
                            } label: {
                                ChatHistoryCardView(session: session)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Obriši", role: .destructive) {
                                    sessions.removeAll { $0.id == session.id }
                                    VorliSessionStore.shared.save(sessions)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("Istorija")
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(.monospaced)
        .toolbar {
            if !sessions.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        sessions = []
                        VorliSessionStore.shared.save([])
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
        .onAppear {
            sessions = VorliSessionStore.shared.load()
        }
    }
}

// MARK: - Preview

#Preview {
    VorliChatView()
        .modelContainer(for: [Receipt.self, Budget.self, BudgetEntry.self, SavingsGoal.self, Wish.self, FixedCost.self], inMemory: true)
}
