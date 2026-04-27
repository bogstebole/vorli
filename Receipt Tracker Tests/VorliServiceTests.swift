import XCTest
@testable import Receipt_Tracker

@MainActor
final class VorliServiceTests: XCTestCase {

    func testSystemPromptContainsKategorizacija() {
        let service = VorliService()
        let profile = VorliUserProfile(
            mesecniPrihod: 0,
            budzetModel: "50/20/30",
            aktivniCilj: "",
            valuta: "RSD",
            lokacija: "Srbija"
        )
        let prompt = service.testableSystemPrompt(userProfile: profile)
        XCTAssertTrue(prompt.contains("KATEGORIZACIJA"),
            "System prompt must contain KATEGORIZACIJA section")
    }

    func testSystemPromptMerchantNames() {
        let service = VorliService()
        let profile = VorliUserProfile(
            mesecniPrihod: 0,
            budzetModel: "50/20/30",
            aktivniCilj: "",
            valuta: "RSD",
            lokacija: "Srbija"
        )
        let prompt = service.testableSystemPrompt(userProfile: profile)
        XCTAssertTrue(prompt.contains("Maxi"), "System prompt must mention Maxi")
        XCTAssertTrue(prompt.contains("Lidl"), "System prompt must mention Lidl")
    }
}
