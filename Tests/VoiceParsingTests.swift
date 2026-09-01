import Foundation
import Testing
@testable import Wealth

struct VoiceParsingTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func readsTheStructuredAnswerIntoAnExpense() throws {
        let parsed = try OpenAIParsingService.parsedExpense(
            fromResponse: completion(#"""
            {"amount":40000,"currency":"ars","note":"Cena con amigos","category":"Food & Drink","date":"2026-08-30"}
            """#),
            categoryNames: ["Food & Drink", "Transport"],
            now: date(2026, 9, 1)
        )
        #expect(parsed.amount == Decimal(40000))
        #expect(parsed.currency == "ARS")
        #expect(parsed.note == "Cena con amigos")
        #expect(parsed.categoryName == "Food & Drink")
        #expect(parsed.date == date(2026, 8, 30))
    }

    @Test func missingAmountIsAParseFailure() {
        let data = completion(#"{"currency":"ARS","note":"súper"}"#)
        #expect(throws: VoiceError.self) {
            try OpenAIParsingService.parsedExpense(fromResponse: data, categoryNames: [], now: .now)
        }
    }

    @Test func zeroAmountIsAParseFailure() {
        let data = completion(#"{"amount":0,"currency":"ARS"}"#)
        #expect(throws: VoiceError.self) {
            try OpenAIParsingService.parsedExpense(fromResponse: data, categoryNames: [], now: .now)
        }
    }

    // A refusal reads differently in the log than a transcript we couldn't parse.
    @Test func aRefusalIsReportedAsARefusal() {
        let data = Data(#"{"choices":[{"message":{"refusal":"I can't help with that"}}]}"#.utf8)
        #expect(throws: VoiceError.refused) {
            try OpenAIParsingService.parsedExpense(fromResponse: data, categoryNames: [], now: .now)
        }
    }

    @Test func anEmptyAnswerIsAParseFailure() {
        let data = Data(#"{"choices":[]}"#.utf8)
        #expect(throws: VoiceError.self) {
            try OpenAIParsingService.parsedExpense(fromResponse: data, categoryNames: [], now: .now)
        }
    }

    @Test func categoryMatchingIgnoresCaseAndAccents() {
        let names = ["Food & Drink", "Salud"]
        #expect(OpenAIParsingService.matchCategory("food & drink", in: names) == "Food & Drink")
        #expect(OpenAIParsingService.matchCategory("salud", in: names) == "Salud")
    }

    @Test func inventedCategoriesAreDropped() {
        #expect(OpenAIParsingService.matchCategory("Crypto", in: ["Food & Drink"]) == nil)
        #expect(OpenAIParsingService.matchCategory(nil, in: ["Food & Drink"]) == nil)
    }

    @Test func sameDayParsesKeepTheCaptureTime() {
        let now = date(2026, 9, 1).addingTimeInterval(14 * 3600)
        #expect(OpenAIParsingService.resolveDate("2026-09-01", now: now) == now)
    }

    @Test func anUnreadableDateFallsBackToNow() {
        let now = date(2026, 9, 1)
        #expect(OpenAIParsingService.resolveDate(nil, now: now) == now)
        #expect(OpenAIParsingService.resolveDate("ayer", now: now) == now)
    }

    @Test func requestNeverPinsALanguageAndListsOnlyRealCategories() throws {
        let body = OpenAIParsingService.requestBody(
            transcript: "cuarenta mil pesos",
            categoryNames: ["Food & Drink", "Transport"],
            defaultCurrency: "ARS",
            now: date(2026, 9, 1)
        )
        let messages = try #require(body["messages"] as? [[String: String]])
        let system = try #require(messages.first { $0["role"] == "system" }?["content"])
        #expect(system.contains("Food & Drink, Transport"))
        #expect(system.contains("never invent a category"))
        #expect(system.contains("2026-09-01"))
        #expect(messages.last?["content"] == "cuarenta mil pesos")
    }

    @Test func requestAsksForAStrictlyEnforcedSchema() throws {
        let body = OpenAIParsingService.requestBody(
            transcript: "mil pesos",
            categoryNames: ["Other"],
            defaultCurrency: "ARS",
            now: .now
        )
        let format = try #require(body["response_format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let schema = try #require(format["json_schema"] as? [String: Any])
        // strict mode is what turns the schema into a guarantee rather than a hint.
        #expect(schema["strict"] as? Bool == true)
        let fields = try #require(schema["schema"] as? [String: Any])
        #expect(fields["additionalProperties"] as? Bool == false)
        let required = try #require(fields["required"] as? [String])
        #expect(Set(required) == Set(["amount", "currency", "note", "category", "date"]))
    }

    @Test func blueRateReadsTheSellingSide() throws {
        let data = Data(#"{"compra":1450,"venta":1485,"nombre":"Blue"}"#.utf8)
        #expect(try APIRateService.blueRate(fromJSON: data) == Decimal(1485))
    }

    @Test func frankfurterRatesAreKeyedByCurrency() throws {
        let data = Data(#"{"base":"USD","rates":{"EUR":0.92}}"#.utf8)
        #expect(try APIRateService.frankfurterRates(fromJSON: data)["EUR"] == Decimal(string: "0.92")!)
    }

    @Test func whisperBodyCarriesTheModelAndFileWithoutALanguagePin() throws {
        let body = WhisperTranscriptionService.multipartBody(boundary: "abc", audioData: Data([0x01, 0x02]))
        let text = try #require(String(bytes: body, encoding: .utf8))
        #expect(text.contains("name=\"model\"\r\n\r\nwhisper-1"))
        #expect(text.contains("filename=\"capture.m4a\""))
        #expect(!text.contains("language"))
        #expect(text.hasSuffix("--abc--\r\n"))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // Structured outputs arrive as a JSON string inside the completion envelope.
    // Fixtures are single-line JSON, so escaping quotes is enough.
    private func completion(_ payload: String) -> Data {
        let escaped = payload.replacingOccurrences(of: "\"", with: "\\\"")
        return Data(#"{"choices":[{"message":{"content":"\#(escaped)"}}]}"#.utf8)
    }
}
