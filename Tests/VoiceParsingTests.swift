import Foundation
import Testing
@testable import Wealth

struct VoiceParsingTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func readsTheServerReplyIntoItems() throws {
        let reply = try ServerAssistantService.reply(
            fromResponse: Data(#"""
            {"transcript":"cena con amigos","items":[{"kind":"expense","action":"create","amount":40000,
            "currency":"ARS","note":"Cena con amigos","category":"Food & Drink","date":"2026-08-30","cadence":null}]}
            """#.split(separator: "\n").joined().utf8),
            status: 200,
            categoryNames: ["Food & Drink", "Transport"],
            now: date(2026, 9, 1)
        )
        #expect(reply.transcript == "cena con amigos")
        let item = try #require(reply.items.first)
        #expect(item.kind == .expense)
        #expect(item.action == .create)
        #expect(item.amount == Decimal(40000))
        #expect(item.categoryName == "Food & Drink")
        #expect(item.date == date(2026, 8, 30))
        #expect(item.cadence == nil)
    }

    @Test func unknownKindsAndActionsFallBackToCreateExpense() throws {
        let reply = try ServerAssistantService.reply(
            fromResponse: Data(#"""
            {"transcript":"x","items":[{"kind":"weird","action":"explode","amount":5,
            "currency":"USD","note":"x","category":null,"date":"2026-09-01","cadence":null}]}
            """#.split(separator: "\n").joined().utf8),
            status: 200,
            categoryNames: [],
            now: date(2026, 9, 1)
        )
        #expect(reply.items.first?.kind == .expense)
        #expect(reply.items.first?.action == .create)
    }

    @Test func noAmountKeepsTheTranscriptWithEmptyItems() throws {
        let reply = try ServerAssistantService.reply(
            fromResponse: Data(#"{"error":"No usable items","code":"no_amount","transcript":"anotá lo del súper"}"#.utf8),
            status: 422,
            categoryNames: [],
            now: .now
        )
        #expect(reply.items.isEmpty)
        #expect(reply.transcript == "anotá lo del súper")
    }

    @Test func nothingHeardIsItsOwnFailure() {
        let data = Data(#"{"error":"Nothing heard","code":"nothing_heard"}"#.utf8)
        #expect(throws: VoiceError.nothingHeard) {
            try ServerAssistantService.reply(fromResponse: data, status: 422, categoryNames: [], now: .now)
        }
    }

    @Test func serverErrorsNameTheServerAndStatus() {
        #expect(throws: VoiceError.requestFailed(service: "Wealth server", status: 502)) {
            try ServerAssistantService.reply(fromResponse: Data(), status: 502, categoryNames: [], now: .now)
        }
    }

    @Test func categoryMatchingIgnoresCaseAndAccents() {
        let names = ["Food & Drink", "Salud"]
        #expect(ServerAssistantService.matchCategory("food & drink", in: names) == "Food & Drink")
        #expect(ServerAssistantService.matchCategory("salud", in: names) == "Salud")
        #expect(ServerAssistantService.matchCategory("Crypto", in: names) == nil)
        #expect(ServerAssistantService.matchCategory(nil, in: names) == nil)
    }

    @Test func sameDayParsesKeepTheCaptureTime() {
        let now = date(2026, 9, 1).addingTimeInterval(14 * 3600)
        #expect(ServerAssistantService.resolveDate("2026-09-01", now: now) == now)
    }

    @Test func anUnreadableDateFallsBackToNow() {
        let now = date(2026, 9, 1)
        #expect(ServerAssistantService.resolveDate(nil, now: now) == now)
        #expect(ServerAssistantService.resolveDate("ayer", now: now) == now)
    }

    @Test func multipartBodyCarriesContextTranscriptAndAudio() throws {
        let body = try ServerAssistantService.multipartBody(
            boundary: "abc",
            context: makeContext(),
            transcript: "nueve mil ochocientos",
            audioData: Data([0x01, 0x02])
        )
        let text = try #require(String(bytes: body, encoding: .isoLatin1))
        #expect(text.contains("name=\"context\""))
        #expect(text.contains("\"today\":\"2026-09-01\""))
        #expect(text.contains("name=\"transcript\"\r\n\r\nnueve mil ochocientos"))
        #expect(text.contains("filename=\"capture.m4a\""))
        #expect(text.hasSuffix("--abc--\r\n"))
    }

    // The server resolves references against these lists; their JSON keys are
    // the contract with server/src/prompt.ts.
    @Test func contextEncodesTheLedgerTheServerExpects() throws {
        let data = try JSONEncoder().encode(makeContext())
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"defaultCurrency\":\"ARS\""))
        #expect(json.contains("\"categories\":[\"Food & Drink\"]"))
        #expect(json.contains("\"name\":\"Claude Pro\""))
        #expect(json.contains("\"note\":\"Café con Juan\""))
        #expect(json.contains("\"recentExpenses\""))
        #expect(json.contains("\"subscriptions\""))
    }

    @Test func blueRateReadsTheSellingSide() throws {
        let data = Data(#"{"compra":1450,"venta":1485,"nombre":"Blue"}"#.utf8)
        #expect(try APIRateService.blueRate(fromJSON: data) == Decimal(1485))
    }

    @Test func frankfurterRatesAreKeyedByCurrency() throws {
        let data = Data(#"{"base":"USD","rates":{"EUR":0.92}}"#.utf8)
        #expect(try APIRateService.frankfurterRates(fromJSON: data)["EUR"] == Decimal(string: "0.92")!)
    }

    private func makeContext() -> ParseContext {
        ParseContext(
            today: "2026-09-01",
            defaultCurrency: "ARS",
            categories: ["Food & Drink"],
            subscriptions: [ParseContext.SubscriptionRef(name: "Claude Pro", amount: 200, currency: "USD", cadence: "monthly")],
            recentExpenses: [ParseContext.ExpenseRef(note: "Café con Juan", amount: 9800, currency: "ARS", date: "2026-08-31")]
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
