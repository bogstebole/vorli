//
//  OCRItemParsingTests.swift
//  Receipt Tracker Tests
//
//  Item-section parsing from raw OCR lines. The Cyrillic case reproduces a
//  real receipt (Domaća trgovina, 03.07.2026) where the column header
//  "Назив Цена Кол. Укупно" used to be swallowed into the first item's name.
//

import Testing
import Foundation
@testable import Receipt_Tracker

struct OCRItemParsingTests {

    @Test func cyrillicColumnHeaderIsNotAnItem() {
        let lines = [
            "========ФИСКАЛНИ РАЧУН========",
            "105696283",
            "DOMAĆA TRGOVINA DOO BEOGRAD",
            "БЕОГРАД (САВСКИ ВЕНАЦ)",
            "Касир:",
            "Marina Maslaković",
            "------ПРОМЕТ ПРОДАЈА------",
            "Артикли",
            "==========================",
            "Назив Цена Кол. Укупно",
            "8606018062423 KLAS RUZA 7 DELOVA 500GR",
            "/ KOM (E)",
            "139,99",
            "1",
            "139,99",
            "46085351 CIGARETE SOBRANIE GOLD (/ KO",
            "М (Ђ)",
            "530,00",
            "1",
            "530,00",
            "--------------------------",
            "Укупан износ:",
            "669,99",
            "Платна картица:",
            "669,99"
        ]

        let items = ReceiptOCRParser.parseLineItems(from: lines)

        #expect(items.count == 2)

        // The column header must not leak into the first item's name.
        let first = items[0]
        #expect(!first.name.contains("Назив"))
        #expect(!first.name.lowercased().contains("naziv"))
        #expect(!first.name.contains("Укупно"))
        // Barcode is stripped from the name.
        #expect(!first.name.contains("8606018062423"))
        #expect(first.name.contains("KLAS RUZA 7 DELOVA 500GR"))
        #expect(first.unitPrice == Decimal(string: "139.99"))
        #expect(first.lineTotal == Decimal(string: "139.99"))

        let second = items[1]
        #expect(second.name.contains("CIGARETE SOBRANIE GOLD"))
        #expect(!second.name.contains("46085351"))
        #expect(second.unitPrice == Decimal(string: "530.00"))
    }

    @Test func latinHeaderStillSkippedAndItemNamesWithHeaderSubstringsSurvive() {
        let lines = [
            "Artikli",
            "Naziv Cena Kol. Ukupno",
            "Pecena paprika",   // contains "cena" as substring — must NOT be treated as header
            "120,00",
            "1",
            "120,00",
            "Ukupan iznos:",
            "120,00"
        ]

        let items = ReceiptOCRParser.parseLineItems(from: lines)

        #expect(items.count == 1)
        #expect(items[0].name == "Pecena paprika")
        #expect(items[0].unitPrice == Decimal(string: "120.00"))
    }

    @Test func summaryLinesEndTheItemsSection() {
        let lines = [
            "Artikli",
            "Naziv Cena Kol. Ukupno",
            "Hleb 500g",
            "75,00",
            "75,00",
            "Плаћено картицом",   // Cyrillic summary marker must stop parsing
            "75,00"
        ]

        let items = ReceiptOCRParser.parseLineItems(from: lines)

        #expect(items.count == 1)
        #expect(items[0].name == "Hleb 500g")
    }
}
