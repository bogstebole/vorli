//
//  VorliService.swift
//  Receipt Tracker
//
//  Anthropic Claude API client with SSE streaming support.
//

import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Card Payload Model

struct VorliCardPayload: Equatable, Codable {
    enum CardType: String, Codable { case pdf, shoppingList }
    enum ActionState: String, Codable { case loading, ready, disabled }

    let cardType: CardType
    var title: String       // Row 1 label, e.g. "PDF izveštaj" (11pt monospaced)
    var mainText: String    // Row 2 prominent text, e.g. "Mart 2026" (14pt monospaced)
    var metaLine: String    // Row 3 meta, e.g. "12 računa · 45.320 RSD" (11pt monospaced, #8A8A82)
    var actionState: ActionState
}

// MARK: - Message Content Type

enum VorliMessageContent: Equatable {
    case text(String)
    case card(VorliCardPayload)
}

extension VorliMessageContent: Codable {
    private enum CodingKeys: String, CodingKey { case type, text, card }
    private enum ContentType: String, Codable { case text, card }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let s):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(s, forKey: .text)
        case .card(let c):
            try container.encode(ContentType.card, forKey: .type)
            try container.encode(c, forKey: .card)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(ContentType.self, forKey: .type)
        switch type_ {
        case .text:
            self = .text(try container.decode(String.self, forKey: .text))
        case .card:
            self = .card(try container.decode(VorliCardPayload.self, forKey: .card))
        }
    }
}

// MARK: - Chat Message Model

struct VorliMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var content: VorliMessageContent

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: VorliMessageContent) {
        self.id = id
        self.role = role
        self.content = content
    }

    /// Returns the text string for .text case; empty string for .card case.
    var textContent: String {
        if case .text(let s) = content { return s }
        return ""
    }
}

extension VorliMessage: Codable {
    private enum CodingKeys: String, CodingKey { case id, role, content }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)

        // Try new discriminated format first; fall back to legacy bare string
        if let c = try? container.decode(VorliMessageContent.self, forKey: .content) {
            content = c
        } else if let legacy = try? container.decode(String.self, forKey: .content) {
            content = .text(legacy)
        } else {
            content = .text("")
        }
    }
}

// MARK: - Time Window Classification

enum TimeWindow: String, CaseIterable {
    case thisMonth  = "this_month"
    case lastMonth  = "last_month"
    case thisWeek   = "this_week"
    case lastWeek   = "last_week"
    case recent     = "recent"
}

// MARK: - API Request/Response Models

private struct AnthropicRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [AnthropicMessage]
    let stream: Bool
}

private struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

private struct StreamDelta: Decodable {
    let type: String
    let text: String?
}

private struct StreamEvent: Decodable {
    let type: String
    let delta: StreamDelta?
}

private struct AnthropicSyncResponse: Decodable {
    let content: [SyncContentBlock]
    struct SyncContentBlock: Decodable {
        let type: String
        let text: String?
    }
}

private struct CardClassificationResponse: Decodable {
    let card: Bool
    let cardType: String?
    let title: String?
    let mainText: String?
    let metaLine: String?
}

// MARK: - Vorli Service

enum VorliError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API ključ nije podešen. Idite u Podešavanja i unesite Anthropic API ključ."
        case .invalidResponse:
            return "Neispravan odgovor od servera."
        case .apiError(let message):
            return message
        }
    }
}

@MainActor
class VorliService {

    static let apiKeyDefaultsKey = "vorli_anthropic_api_key"

    private let model = "claude-sonnet-4-20250514"
    private let classificationModel = "claude-haiku-4-5-20251001"
    private let maxTokens = 2048

    // MARK: - System Prompt

    private func buildSystemPrompt(userProfile: VorliUserProfile) -> String {
        """
        Ti si Vorli, finansijski asistent unutar iOS aplikacije za praćenje troškova.
        Korisnik govori srpski — uvek odgovaraj na srpskom.

        TON: direktan, konkretan, bez finansijskog žargona. Kao prijatelj koji razume pare.
        FORMAT: direktno na postu → ključni nalazi → jedan konkretan savet.
        NIKAD ne pravi liste od više od 5 stavki. Manje je više.
        UVOD: nikad ne počinjaj odgovor sa "Pretrazio sam..." ili "U podacima koje imam..." — to je podrazumevano. Počni direktno sa odgovorom.
        LISTE: uvek koristi markdown format (- stavka) za nabrajanja, nikad inline bullet karaktere (•) u tekstu.

        Za izveštaje: uvek poredi sa prethodnim periodom ako postoje podaci.
        Za planove: razdvoji bulk kupovinu (jednom mesečno) od svežeg (nedeljno).
        Za insights: budi specifičan — napiši iznos, procenat, datum, prodavnicu.
        Na kraju svakog izveštaja ili plana: jedan konkretan savet za naredni period.

        === TAČNOST PODATAKA — OBAVEZNO ===
        Podaci su u JSON polju "racuni_period" (i "racuni_prethodni" za poređenje).
        Polje "meta" sadrži tačan datum danas, ukupan broj računa i raspon datuma — uvek koristi ove podatke.

        PRETRAGA PO KATEGORIJI:
        Kada tražiš kategoriju (gorivo, namirnice, restoran, itd.), pretraži I naziv prodavnice I SVE stavke (stavke[].naziv) svakog računa.
        Srpske benzinske pumpe koriste sledeće nazive stavki — sve ovo je gorivo:
          - EVRO DIZEL, EVRO DIZEL 10, DIZEL
          - BMB 95, EUROSUPER BS 95, EVRO SUPER 98, EVRO PREMIUM 100
          - LPG, AUTO GAS
          - Prodavnice: NIS, NIS Petrol, MOL, OMV, GAZPROM, LUKOIL, ENIS

        Ako ne nađeš tražene račune, napiši tačno: "U podacima koje imam (N računa, od [datum] do [datum]) nema računa koji odgovaraju." — popuni N i datume iz meta polja. Samo u tom slučaju navodi ukupan broj računa i period.
        NIKAD ne izmišljaj, ne pretpostavljaj, ne dodavaj podatke kojih nema u JSON-u.

        === KATEGORIZACIJA ===
        Kada korisnik pita za kategoriju troška, zaključi kategoriju na osnovu NAZIVA PRODAVNICE i NAZIVA STAVKI.
        NIKAD ne vrati "N/A" za kategoriju — uvek zaključi na osnovu dostupnih podataka.

        Poznate prodavnice po kategorijama:
        - Namirnice: Maxi, Lidl, Roda, Idea, DP, Univerexport, Mercator, Tempo
        - Apoteke / kozmetika: DM, Lilly, Biljka
        - Gorivo: NIS, NIS Petrol, OMV, MOL, Lukoil, Gazprom, Enis
        - Brza hrana: McDonald's, KFC, Burger King, Pizza Hut

        Za ostale prodavnice, zaključi kategoriju iz naziva stavki (npr. "HLEB", "MLEKO" → namirnice).

        Korisnički profil:
        - Mesečni prihod: \(userProfile.mesecniPrihod > 0 ? "\(userProfile.mesecniPrihod) RSD" : "nije unet")
        - Budžet model: \(userProfile.budzetModel)
        - Valuta: \(userProfile.valuta)
        - Lokacija: \(userProfile.lokacija)
        """
    }

    // MARK: - Streaming Send

    /// Streams a response from the Claude API, calling `onToken` for each text chunk.
    func sendMessage(
        userMessage: String,
        context: String,
        history: [VorliMessage],
        userProfile: VorliUserProfile,
        onToken: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor () -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        let apiKey = UserDefaults.standard.string(forKey: Self.apiKeyDefaultsKey) ?? ""
        guard !apiKey.isEmpty else {
            onError(VorliError.missingAPIKey)
            return
        }

        // Build messages array from history + new user message with context
        var messages: [AnthropicMessage] = history.map {
            AnthropicMessage(role: $0.role == .user ? "user" : "assistant", content: $0.textContent)
        }

        // Inject receipt context into the user message
        let fullUserMessage = context.isEmpty
            ? userMessage
            : "\(userMessage)\n\n---\nKontekst podataka:\n\(context)"

        messages.append(AnthropicMessage(role: "user", content: fullUserMessage))

        let request = AnthropicRequest(
            model: model,
            max_tokens: maxTokens,
            system: buildSystemPrompt(userProfile: userProfile),
            messages: messages,
            stream: true
        )

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            onError(error)
            return
        }

        Task {
            do {
                let (asyncBytes, response) = try await URLSession.shared.bytes(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run { onError(VorliError.invalidResponse) }
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    var body = ""
                    for try await line in asyncBytes.lines { body += line }
                    await MainActor.run {
                        onError(VorliError.apiError("HTTP \(httpResponse.statusCode): \(body)"))
                    }
                    return
                }

                for try await line in asyncBytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let jsonString = String(line.dropFirst(6))
                    guard jsonString != "[DONE]" else { break }

                    guard let data = jsonString.data(using: .utf8),
                          let event = try? JSONDecoder().decode(StreamEvent.self, from: data)
                    else { continue }

                    if event.type == "content_block_delta",
                       let text = event.delta?.text {
                        await MainActor.run { onToken(text) }
                    }
                }

                await MainActor.run { onComplete() }

            } catch {
                await MainActor.run { onError(error) }
            }
        }
    }

    // MARK: - Intent Classification

    /// Classifies the time window for a free-text question using a non-streaming Haiku call.
    /// Falls back to `.recent` silently on any error or missing API key.
    func classifyIntent(question: String) async -> TimeWindow {
        let apiKey = UserDefaults.standard.string(forKey: Self.apiKeyDefaultsKey) ?? ""
        guard !apiKey.isEmpty else { return .recent }

        let systemPrompt = """
        Klasifikuj vremenski period koji korisnik traži u JEDNOJ od sledećih vrednosti:
        this_month | last_month | this_week | last_week | recent
        Odgovori SAMO jednom od tih vrednosti — bez objašnjenja.
        """

        let request = AnthropicRequest(
            model: classificationModel,
            max_tokens: 10,
            system: systemPrompt,
            messages: [AnthropicMessage(role: "user", content: question)],
            stream: false
        )

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return .recent }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            let parsed = try JSONDecoder().decode(AnthropicSyncResponse.self, from: data)
            let raw = parsed.content
                .first(where: { $0.type == "text" })?
                .text?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "recent"
            return TimeWindow(rawValue: raw) ?? .recent
        } catch {
            return .recent  // silent fallback on any error
        }
    }

    // MARK: - Card Intent Classification

    /// Returns a VorliCardPayload if the conversation warrants an action card, nil otherwise.
    /// Uses Haiku for a fast, cheap classification after the main response completes.
    func classifyCardIntent(userMessage: String, assistantResponse: String) async -> VorliCardPayload? {
        let apiKey = UserDefaults.standard.string(forKey: Self.apiKeyDefaultsKey) ?? ""
        guard !apiKey.isEmpty else { return nil }

        let systemPrompt = """
        Analiziraj poruku korisnika i odgovor asistenta.
        Odluči da li odgovor zahteva akcijsku karticu (dugme za akciju).

        Kartica se kreira SAMO kada odgovor:
        - Sadrži mesečni ili nedeljni izveštaj potrošnje → cardType: "pdf"
        - Sadrži listu za kupovinu ili preporuku šta kupiti → cardType: "shoppingList"

        Ako kartica treba, vrati JSON:
        {"card":true,"cardType":"pdf","title":"PDF izveštaj","mainText":"Mart 2026","metaLine":"12 računa · 45.320 RSD"}

        mainText: period izveštaja (npr. "Mart 2026") ili naziv liste
        metaLine: broj računa i ukupan iznos ako je dostupan, inače kratak opis

        Ako kartica NIJE potrebna, vrati tačno: {"card":false}
        Odgovori SAMO validnim JSON-om — bez objašnjenja.
        """

        let combined = "Korisnik: \(userMessage)\n\nAsistent: \(assistantResponse)"
        let request = AnthropicRequest(
            model: classificationModel,
            max_tokens: 120,
            system: systemPrompt,
            messages: [AnthropicMessage(role: "user", content: combined)],
            stream: false
        )

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return nil }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                debugLog("[VorliCard] API error \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                return nil
            }
            let parsed = try JSONDecoder().decode(AnthropicSyncResponse.self, from: data)
            guard let raw = parsed.content.first(where: { $0.type == "text" })?.text else {
                debugLog("[VorliCard] no text block in response")
                return nil
            }
            var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            // Strip markdown code fences Haiku sometimes adds (```json ... ```)
            if trimmed.hasPrefix("```") {
                trimmed = trimmed
                    .components(separatedBy: "\n")
                    .dropFirst()
                    .joined(separator: "\n")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            debugLog("[VorliCard] classification response: \(trimmed)")
            guard let jsonData = trimmed.data(using: .utf8),
                  let obj = try? JSONDecoder().decode(CardClassificationResponse.self, from: jsonData),
                  obj.card else { return nil }
            return VorliCardPayload(
                cardType: VorliCardPayload.CardType(rawValue: obj.cardType ?? "pdf") ?? .pdf,
                title: obj.title ?? "Izveštaj",
                mainText: obj.mainText ?? "",
                metaLine: obj.metaLine ?? "",
                actionState: .ready
            )
        } catch {
            debugLog("[VorliCard] error: \(error)")
            return nil
        }
    }

    // MARK: - Testing Support

    #if DEBUG
    func testableSystemPrompt(userProfile: VorliUserProfile) -> String {
        buildSystemPrompt(userProfile: userProfile)
    }
    #endif
}

// MARK: - User Profile

struct BudzetModelJSON: Encodable {
    let potrebe: Int    // "needs" percentage (first component)
    let zabava: Int     // "entertainment" percentage (second component)
    let stednja: Int    // "savings" percentage (third component)
}

struct VorliUserProfile {
    var mesecniPrihod: Int
    var budzetModel: String
    var aktivniCilj: String
    var valuta: String
    var lokacija: String

    static let defaultsKeyPrefix = "vorli_profile_"

    static func load() -> VorliUserProfile {
        let defaults = UserDefaults.standard
        return VorliUserProfile(
            mesecniPrihod: defaults.integer(forKey: defaultsKeyPrefix + "prihod"),
            budzetModel: defaults.string(forKey: defaultsKeyPrefix + "budzet") ?? "50/20/30",
            aktivniCilj: defaults.string(forKey: defaultsKeyPrefix + "cilj") ?? "",
            valuta: "RSD",
            lokacija: "Srbija"
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(mesecniPrihod, forKey: Self.defaultsKeyPrefix + "prihod")
        defaults.set(budzetModel, forKey: Self.defaultsKeyPrefix + "budzet")
        defaults.set(aktivniCilj, forKey: Self.defaultsKeyPrefix + "cilj")
    }

    var parsedBudzetModel: BudzetModelJSON {
        let components = budzetModel.split(separator: "/").compactMap { Int($0) }
        guard components.count >= 3 else {
            return BudzetModelJSON(potrebe: 50, zabava: 30, stednja: 20)
        }
        return BudzetModelJSON(potrebe: components[0], zabava: components[1], stednja: components[2])
    }
}

// MARK: - Transferable Report

struct VorliReport: Transferable {
    let period: String
    let metaLine: String
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { report in
            await MainActor.run {
                VorliPDFGenerator.generate(
                    period: report.period,
                    metaLine: report.metaLine,
                    reportText: report.text
                )
            }
        }
    }
}

// MARK: - PDF Generator

@MainActor
enum VorliPDFGenerator {

    static func generate(period: String, metaLine: String, reportText: String) -> Data {
        let pageW: CGFloat = 595.2
        let pageH: CGFloat = 841.8
        let margin: CGFloat = 56
        let contentW = pageW - 2 * margin

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        return renderer.pdfData { ctx in
            var y: CGFloat = margin
            ctx.beginPage()

            func blockHeight(_ str: NSAttributedString) -> CGFloat {
                ceil(str.boundingRect(
                    with: CGSize(width: contentW, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).height)
            }

            func drawBlock(_ str: NSAttributedString) {
                let h = blockHeight(str)
                if y + h > pageH - margin { ctx.beginPage(); y = margin }
                str.draw(in: CGRect(x: margin, y: y, width: contentW, height: h))
                y += h
            }

            func drawRule() {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: y))
                path.addLine(to: CGPoint(x: pageW - margin, y: y))
                UIColor.separator.setStroke()
                path.lineWidth = 0.5
                path.stroke()
            }

            // ── Header ───────────────────────────────────────────────────
            drawBlock(NSAttributedString(string: "VORLI · FINANSIJSKI IZVEŠTAJ", attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel,
                .kern: 0.8
            ]))
            y += 8
            drawBlock(NSAttributedString(string: period, attributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.label
            ]))
            y += 4
            drawBlock(NSAttributedString(string: metaLine, attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]))
            y += 16
            drawRule()
            y += 20

            // ── Content ──────────────────────────────────────────────────
            for block in parseBlocks(reportText) {
                switch block {
                case .heading(let lvl, let text):
                    y += lvl <= 2 ? 16 : 10
                    let fontSize: CGFloat = lvl == 1 ? 16 : (lvl == 2 ? 14 : 12)
                    let weight: UIFont.Weight = lvl <= 2 ? .semibold : .medium
                    drawBlock(NSAttributedString(string: text, attributes: [
                        .font: UIFont.systemFont(ofSize: fontSize, weight: weight),
                        .foregroundColor: UIColor.label
                    ]))
                    y += 4

                case .bulletItem(let text):
                    y += 2
                    let str = NSMutableAttributedString(string: "•  ", attributes: [
                        .font: UIFont.systemFont(ofSize: 12),
                        .foregroundColor: UIColor.secondaryLabel
                    ])
                    str.append(NSAttributedString(string: text, attributes: [
                        .font: UIFont.systemFont(ofSize: 12),
                        .foregroundColor: UIColor.label
                    ]))
                    let para = NSMutableParagraphStyle()
                    para.headIndent = 14
                    str.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: str.length))
                    drawBlock(str)

                case .numberedItem(let n, let text):
                    y += 2
                    let str = NSMutableAttributedString(string: "\(n).  ", attributes: [
                        .font: UIFont.systemFont(ofSize: 12),
                        .foregroundColor: UIColor.secondaryLabel
                    ])
                    str.append(NSAttributedString(string: text, attributes: [
                        .font: UIFont.systemFont(ofSize: 12),
                        .foregroundColor: UIColor.label
                    ]))
                    drawBlock(str)

                case .paragraph(let text):
                    y += 6
                    drawBlock(NSAttributedString(string: text, attributes: [
                        .font: UIFont.systemFont(ofSize: 12),
                        .foregroundColor: UIColor.label
                    ]))

                case .codeBlock(let code):
                    y += 8
                    drawBlock(NSAttributedString(string: code, attributes: [
                        .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                        .foregroundColor: UIColor.label
                    ]))
                    y += 8
                }
            }

            // ── Footer ───────────────────────────────────────────────────
            y += 32
            if y > pageH - margin - 24 { ctx.beginPage(); y = margin }
            drawRule()
            y += 10
            let df = DateFormatter()
            df.locale = Locale(identifier: "sr_Latn_RS")
            df.dateStyle = .long
            drawBlock(NSAttributedString(string: "Generisao Vorli · \(df.string(from: Date()))", attributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.tertiaryLabel
            ]))
        }
    }

    // MARK: - Markdown block parser

    private enum PDFBlock {
        case heading(level: Int, content: String)
        case bulletItem(content: String)
        case numberedItem(number: Int, content: String)
        case codeBlock(code: String)
        case paragraph(content: String)
    }

    private static func parseBlocks(_ text: String) -> [PDFBlock] {
        var blocks: [PDFBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        let numberedPattern = /^(\d+)\.\s(.+)/

        while i < lines.count {
            let line = lines[i]

            if line.hasPrefix("```") {
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") { code.append(lines[i]); i += 1 }
                blocks.append(.codeBlock(code: code.joined(separator: "\n")))
                i += 1; continue
            }
            if line.hasPrefix("#") {
                let lvl = line.prefix(while: { $0 == "#" }).count
                blocks.append(.heading(level: min(lvl, 3), content: String(line.dropFirst(lvl)).trimmingCharacters(in: .whitespaces)))
                i += 1; continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                blocks.append(.bulletItem(content: String(line.dropFirst(2))))
                i += 1; continue
            }
            if let m = line.firstMatch(of: numberedPattern) {
                blocks.append(.numberedItem(number: Int(m.1) ?? 1, content: String(m.2)))
                i += 1; continue
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty { i += 1; continue }

            var para = [line]; i += 1
            while i < lines.count {
                let next = lines[i]
                if next.trimmingCharacters(in: .whitespaces).isEmpty || next.hasPrefix("#")
                    || next.hasPrefix("- ") || next.hasPrefix("* ") || next.hasPrefix("```")
                    || next.firstMatch(of: numberedPattern) != nil { break }
                para.append(next); i += 1
            }
            blocks.append(.paragraph(content: para.joined(separator: " ")))
        }
        return blocks
    }
}
