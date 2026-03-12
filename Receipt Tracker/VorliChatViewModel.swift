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

@Observable
@MainActor
final class VorliChatViewModel {

    // MARK: - State

    var messages: [VorliMessage] = []
    var isStreaming = false
    var errorMessage: String?
    var showError = false

    // MARK: - Private

    private let service = VorliService()
    private let allReceipts: [Receipt]

    init(allReceipts: [Receipt]) {
        self.allReceipts = allReceipts
    }

    // MARK: - Send

    func send(_ text: String, requestType: String = "PRETRAGA") {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard !isStreaming else { return }

        // Append user message
        let userMsg = VorliMessage(role: .user, content: text)
        messages.append(userMsg)

        // Build receipt context based on request type
        let context = buildContext(for: requestType)

        // Append empty assistant message to stream into
        let assistantMsg = VorliMessage(role: .assistant, content: "")
        messages.append(assistantMsg)
        let assistantIndex = messages.count - 1

        isStreaming = true

        let history = Array(messages.dropLast(2)) // exclude the pair we just added

        service.sendMessage(
            userMessage: text,
            context: context,
            history: history,
            userProfile: VorliUserProfile.load(),
            onToken: { [weak self] token in
                guard let self else { return }
                self.messages[assistantIndex].content += token
            },
            onComplete: { [weak self] in
                self?.isStreaming = false
            },
            onError: { [weak self] error in
                guard let self else { return }
                self.isStreaming = false
                // Remove the empty assistant placeholder
                if self.messages.last?.content.isEmpty == true {
                    self.messages.removeLast()
                }
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        )
    }

    // MARK: - Quick Prompts

    func sendQuickPrompt(_ prompt: QuickPrompt) {
        send(prompt.userMessage, requestType: prompt.requestType)
    }

    // MARK: - Context Builder

    private func buildContext(for requestType: String) -> String {
        switch requestType {
        case "REPORT_MONTH":
            let current = VorliContextBuilder.receiptsForCurrentMonth(from: allReceipts)
            let previous = VorliContextBuilder.receiptsForPreviousMonth(from: allReceipts)
            return VorliContextBuilder.build(currentReceipts: current, previousReceipts: previous, requestType: "REPORT")

        case "REPORT_WEEK":
            let current = VorliContextBuilder.receiptsForCurrentWeek(from: allReceipts)
            let previous = VorliContextBuilder.receiptsForPreviousWeek(from: allReceipts)
            return VorliContextBuilder.build(currentReceipts: current, previousReceipts: previous, requestType: "REPORT")

        default:
            // For free-text search, send receipts from last 6 months as context
            let cutoff = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
            let recent = allReceipts.filter { $0.timestamp >= cutoff }
            return VorliContextBuilder.build(currentReceipts: recent, requestType: "PRETRAGA")
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
