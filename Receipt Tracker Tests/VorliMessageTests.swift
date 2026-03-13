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
        XCTFail("RED — not implemented yet")
    }

    // Test 2: Construct JSON with a bare string `"content": "hello"` (old format,
    // no `type` key), decode it, assert result is .text("hello") — not a crash.
    func testVorliMessageBackwardCompatDecode() throws {
        XCTFail("RED — not implemented yet")
    }

    // Test 3: Create a VorliChatViewModel, call emitCard(payload),
    // assert messages.last?.content == .card(payload).
    func testEmitCardAppendsCardMessage() {
        XCTFail("RED — not implemented yet")
    }

    // Test 4: Call emitCard with .loading state, then updateCardState to .ready,
    // assert messages.last has .ready actionState.
    func testUpdateCardStateTransitionsActionState() {
        XCTFail("RED — not implemented yet")
    }
}
