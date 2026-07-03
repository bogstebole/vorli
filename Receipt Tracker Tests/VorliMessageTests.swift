//
//  VorliMessageTests.swift
//  Receipt Tracker Tests
//
//  TDD tests for VorliMessage typed content model (Phase 3, Plan 01).
//

import XCTest
@testable import Receipt_Tracker

@MainActor
final class VorliMessageTests: XCTestCase {

    // Test 1: Encode a VorliMessage with .card(VorliCardPayload), decode it back,
    // assert content equals the original .card case.
    func testVorliMessageCardCodableRoundtrip() throws {
        let payload = VorliCardPayload(
            cardType: .pdf,
            title: "PDF izveštaj",
            mainText: "Mart 2026",
            metaLine: "12 računa · 45.320 RSD",
            actionState: .ready
        )
        let original = VorliMessage(role: .assistant, content: .card(payload))

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VorliMessage.self, from: encoded)

        XCTAssertEqual(decoded.content, original.content,
            "Decoded card content must equal the original card payload")
        if case .card(let decodedPayload) = decoded.content {
            XCTAssertEqual(decodedPayload.title, "PDF izveštaj")
            XCTAssertEqual(decodedPayload.mainText, "Mart 2026")
            XCTAssertEqual(decodedPayload.actionState, .ready)
        } else {
            XCTFail("Expected .card content after roundtrip, got something else")
        }
    }

    // Test 2: Construct JSON with a bare string `"content": "hello"` (old format,
    // no `type` key), decode it, assert result is .text("hello") — not a crash.
    func testVorliMessageBackwardCompatDecode() throws {
        let legacyJSON = """
        {"id":"550E8400-E29B-41D4-A716-446655440000","role":"assistant","content":"legacy text"}
        """
        let data = legacyJSON.data(using: .utf8)!
        let message = try JSONDecoder().decode(VorliMessage.self, from: data)

        XCTAssertEqual(message.textContent, "legacy text",
            "Legacy bare-string content must decode to .text(\"legacy text\")")
        if case .text(let s) = message.content {
            XCTAssertEqual(s, "legacy text")
        } else {
            XCTFail("Expected .text content from legacy format, got something else")
        }
    }

    // Test 3: Create a VorliChatViewModel, call emitCard(payload),
    // assert messages.last?.content == .card(payload).
    func testEmitCardAppendsCardMessage() async {
        let viewModel = VorliChatViewModel(allReceipts: [], stanje: nil)
        let payload = VorliCardPayload(
            cardType: .shoppingList,
            title: "Lista kupovine",
            mainText: "Mart 2026",
            metaLine: "5 artikala",
            actionState: .loading
        )

        viewModel.emitCard(payload)

        XCTAssertEqual(viewModel.messages.count, 1,
            "emitCard should append exactly one message")
        XCTAssertEqual(viewModel.messages[0].role, .assistant,
            "Emitted card message must have assistant role")
        XCTAssertEqual(viewModel.messages[0].content, .card(payload),
            "Emitted card message content must equal the provided payload")
    }

    // Test 4: Call emitCard with .loading state, then updateCardState to .ready,
    // assert messages.last has .ready actionState.
    func testUpdateCardStateTransitionsActionState() async {
        let viewModel = VorliChatViewModel(allReceipts: [], stanje: nil)
        let payload = VorliCardPayload(
            cardType: .pdf,
            title: "PDF izveštaj",
            mainText: "Februar 2026",
            metaLine: "8 računa",
            actionState: .loading
        )

        viewModel.emitCard(payload)
        let messageID = viewModel.messages[0].id

        viewModel.updateCardState(messageID: messageID, newState: .ready)

        if case .card(let updatedPayload) = viewModel.messages[0].content {
            XCTAssertEqual(updatedPayload.actionState, .ready,
                "updateCardState must transition actionState from .loading to .ready")
        } else {
            XCTFail("Expected .card content after updateCardState")
        }
    }
}
