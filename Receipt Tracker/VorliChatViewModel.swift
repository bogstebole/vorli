//
//  VorliChatViewModel.swift
//  Receipt Tracker
//
//  ViewModel for the Vorli AI chat screen. Owns message state, streaming,
//  and receipt context building.
//

import Foundation
import SwiftData
import Observation

// MARK: - Chat Session

struct VorliChatSession: Identifiable, Codable {
    var id: UUID
    var title: String
    var date: Date
    var messages: [VorliMessage]

    init(id: UUID = UUID(), title: String, date: Date = Date(), messages: [VorliMessage]) {
        self.id = id
        self.title = title
        self.date = date
        self.messages = messages
    }

    /// First user message clipped at the first sentence boundary (., ?, !).
    /// Falls back to the raw text if no punctuation is found — lineLimit(1) handles visual truncation.
    var subtitle: String {
        guard let first = messages.first(where: { $0.role == .user })?.textContent else { return "" }
        let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
        // Find the first sentence-ending punctuation
        if let range = trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: ".?!")) {
            let sentence = String(trimmed[trimmed.startIndex...range.lowerBound])
            return sentence.trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }
}

// MARK: - Session Store

final class VorliSessionStore {
    static let shared = VorliSessionStore()
    private let key = "vorli_chat_sessions"

    func load() -> [VorliChatSession] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let sessions = try? JSONDecoder().decode([VorliChatSession].self, from: data)
        else { return [] }
        return sessions
    }

    func save(_ sessions: [VorliChatSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func append(_ session: VorliChatSession) {
        var sessions = load()
        // Replace if same id, otherwise prepend
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
        } else {
            sessions.insert(session, at: 0)
        }
        // Keep at most 50 sessions
        if sessions.count > 50 { sessions = Array(sessions.prefix(50)) }
        save(sessions)
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class VorliChatViewModel {

    // MARK: - State

    var messages: [VorliMessage] = []
    var isStreaming = false
    var errorMessage: String?
    var showError = false

    /// Title derived from the first user message of the current conversation.
    var conversationTitle: String = "Vorli"

    // MARK: - Private

    private let service = VorliService()
    private let allReceipts: [Receipt]
    private let budget: Budget?
    private var sessionID = UUID()

    init(allReceipts: [Receipt], budget: Budget? = nil) {
        self.allReceipts = allReceipts
        self.budget = budget
    }

    // MARK: - New Chat

    func startNewChat() {
        saveCurrentSessionIfNeeded()
        messages = []
        conversationTitle = "Vorli"
        sessionID = UUID()
    }

    // MARK: - Load Session

    func load(session: VorliChatSession) {
        saveCurrentSessionIfNeeded()
        sessionID = session.id
        messages = session.messages
        conversationTitle = session.title
    }

    // MARK: - Save current session

    func saveCurrentSessionIfNeeded() {
        guard !messages.isEmpty else { return }
        let session = VorliChatSession(
            id: sessionID,
            title: conversationTitle,
            date: Date(),
            messages: messages
        )
        VorliSessionStore.shared.append(session)
    }

    // MARK: - Send

    func send(_ text: String, requestType: String = "PRETRAGA", savingsGoals: [SavingsGoal] = []) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard !isStreaming else { return }

        // Append user message
        let userMsg = VorliMessage(role: .user, content: .text(text))
        messages.append(userMsg)

        // Set title from first user message (truncated to 40 chars)
        if conversationTitle == "Vorli" {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            conversationTitle = trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : trimmed
        }

        // Set BEFORE entering async Task to prevent double-send
        isStreaming = true

        let history = Array(messages.dropLast()) // exclude the user message we just added

        Task { @MainActor in
            // Classify intent for free-text queries; quick prompts bypass classification
            let window: TimeWindow
            switch requestType {
            case "REPORT_MONTH": window = .thisMonth
            case "REPORT_WEEK":  window = .thisWeek
            case "PRETRAGA":     window = await service.classifyIntent(question: text)
            default:             window = TimeWindow(rawValue: requestType) ?? .recent
            }

            let context = buildContext(for: window, savingsGoals: savingsGoals)

            // Append empty assistant message to stream into
            let assistantMsg = VorliMessage(role: .assistant, content: .text(""))
            messages.append(assistantMsg)
            let assistantIndex = messages.count - 1

            service.sendMessage(
                userMessage: text,
                context: context,
                history: history,
                userProfile: VorliUserProfile.load(),
                onToken: { [weak self] token in
                    guard let self else { return }
                    self.messages[assistantIndex].content = .text(self.messages[assistantIndex].textContent + token)
                },
                onComplete: { [weak self] in
                    guard let self else { return }
                    self.isStreaming = false
                    let finalText = self.messages[assistantIndex].textContent
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        print("[VorliCard] checking card intent, response length: \(finalText.count)")
                        if let card = await self.service.classifyCardIntent(
                            userMessage: text,
                            assistantResponse: finalText
                        ) {
                            print("[VorliCard] emitting card: \(card)")
                            self.emitCard(card)
                        } else {
                            print("[VorliCard] no card warranted")
                        }
                    }
                },
                onError: { [weak self] error in
                    guard let self else { return }
                    self.isStreaming = false
                    if self.messages.last?.textContent.isEmpty == true {
                        self.messages.removeLast()
                    }
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            )
        }
    }

    // MARK: - Card Emission

    /// Called when Vorli decides to emit a card instead of a text response.
    func emitCard(_ payload: VorliCardPayload) {
        let cardMsg = VorliMessage(role: .assistant, content: .card(payload))
        messages.append(cardMsg)
    }

    /// Updates actionState on an existing card message (e.g. loading → ready after PDF generation).
    func updateCardState(messageID: UUID, newState: VorliCardPayload.ActionState) {
        guard let idx = messages.firstIndex(where: { $0.id == messageID }),
              case .card(var payload) = messages[idx].content else { return }
        payload.actionState = newState
        messages[idx].content = .card(payload)
    }

    // MARK: - Quick Prompts

    func sendQuickPrompt(_ prompt: QuickPrompt, savingsGoals: [SavingsGoal] = []) {
        send(prompt.userMessage, requestType: prompt.requestType, savingsGoals: savingsGoals)
    }

    // MARK: - Context Builder

    private func buildContext(for window: TimeWindow, savingsGoals: [SavingsGoal] = []) -> String {
        let profile = VorliUserProfile.load()
        switch window {
        case .thisMonth:
            let current = VorliContextBuilder.receiptsForCurrentMonth(from: allReceipts)
            let previous = VorliContextBuilder.receiptsForPreviousMonth(from: allReceipts)
            return VorliContextBuilder.build(currentReceipts: current, previousReceipts: previous, requestType: "REPORT", budget: budget, userProfile: profile, savingsGoals: savingsGoals)

        case .lastMonth:
            let lastMonth = VorliContextBuilder.receiptsForPreviousMonth(from: allReceipts)
            return VorliContextBuilder.build(currentReceipts: lastMonth, requestType: "PRETRAGA", budget: budget, userProfile: profile, savingsGoals: savingsGoals)

        case .thisWeek:
            let current = VorliContextBuilder.receiptsForCurrentWeek(from: allReceipts)
            let previous = VorliContextBuilder.receiptsForPreviousWeek(from: allReceipts)
            return VorliContextBuilder.build(currentReceipts: current, previousReceipts: previous, requestType: "REPORT", budget: budget, userProfile: profile, savingsGoals: savingsGoals)

        case .lastWeek:
            let lastWeek = VorliContextBuilder.receiptsForPreviousWeek(from: allReceipts)
            return VorliContextBuilder.build(currentReceipts: lastWeek, requestType: "PRETRAGA", budget: budget, userProfile: profile, savingsGoals: savingsGoals)

        case .recent:
            let cutoff = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
            let recent = allReceipts.filter { $0.timestamp >= cutoff }
            return VorliContextBuilder.build(currentReceipts: recent, requestType: "PRETRAGA", budget: budget, userProfile: profile, savingsGoals: savingsGoals)
        }
    }
}

// MARK: - Quick Prompts

struct QuickPrompt: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let userMessage: String
    let requestType: String
}

extension QuickPrompt {
    static let all: [QuickPrompt] = [
        QuickPrompt(
            title: "Mesečni izveštaj",
            subtitle: "Ovaj mesec",
            icon: "chart.bar.fill",
            userMessage: "Generiši detaljan izveštaj potrošnje za ovaj mesec. Prikaži ukupan iznos, top prodavnice, i poredi sa prošlim mesecom.",
            requestType: "REPORT_MONTH"
        ),
        QuickPrompt(
            title: "Nedeljni izveštaj",
            subtitle: "Ova nedelja",
            icon: "calendar.badge.clock",
            userMessage: "Generiši izveštaj za ovu nedelju. Fokusiraj se na anomalije i trendove u potrošnji.",
            requestType: "REPORT_WEEK"
        ),
        QuickPrompt(
            title: "Gde trošim najviše?",
            subtitle: "Top prodavnice",
            icon: "cart.fill",
            userMessage: "U kojim prodavnicama sam potrošio najviše novca? Prikaži top 5 sa iznosima.",
            requestType: "PRETRAGA"
        ),
        QuickPrompt(
            title: "Analiza navika",
            subtitle: "Insights",
            icon: "brain.head.profile",
            userMessage: "Analiziraj moje navike potrošnje i daj mi 3 konkretna uvida o tome kako i gde trošim pare.",
            requestType: "PRETRAGA"
        ),
        QuickPrompt(
            title: "Najskuplji artikli",
            subtitle: "Top troškovi",
            icon: "arrow.up.circle.fill",
            userMessage: "Koji su moji najskuplji pojedinačni artikli ili kupovine? Prikaži top 5.",
            requestType: "PRETRAGA"
        )
    ]
}
