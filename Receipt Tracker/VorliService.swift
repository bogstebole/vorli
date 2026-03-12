//
//  VorliService.swift
//  Receipt Tracker
//
//  Anthropic Claude API client with SSE streaming support.
//

import Foundation

// MARK: - Chat Message Model

struct VorliMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var content: String

    enum Role {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
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
    private let maxTokens = 2048

    // MARK: - System Prompt

    private func buildSystemPrompt(userProfile: VorliUserProfile) -> String {
        """
        Ti si Vorli, finansijski asistent unutar iOS aplikacije za praćenje troškova.
        Korisnik govori srpski — uvek odgovaraj na srpskom.

        TON: direktan, konkretan, bez finansijskog žargona. Kao prijatelj koji razume pare.
        FORMAT: kratak uvod (1 rečenica) → ključni nalazi → jedan konkretan savet.
        NIKAD ne pravi liste od više od 5 stavki. Manje je više.

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

        NIKAD ne reci "nema rezultata" a da pre toga nisi eksplicitno naveo:
          1. Koliko ukupno računa si pregledao
          2. Koji vremenski period pokrivaju ti podaci (uzmi iz meta.datum_najstarijeg i meta.datum_najnovijeg)
          3. Koje ključne reči si tražio

        Ako ne nađeš tražene račune, napiši tačno: "U podacima koje imam (N računa, od [datum] do [datum]) nema računa koji odgovaraju." — popuni N i datume iz meta polja.
        NIKAD ne izmišljaj, ne pretpostavljaj, ne dodavaj podatke kojih nema u JSON-u.

        Korisnički profil:
        - Mesečni prihod: \(userProfile.mesecniPrihod > 0 ? "\(userProfile.mesecniPrihod) RSD" : "nije unet")
        - Budžet model: \(userProfile.budzetModel)
        - Aktivni cilj: \(userProfile.aktivniCilj.isEmpty ? "nije postavljen" : userProfile.aktivniCilj)
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
            AnthropicMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content)
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
