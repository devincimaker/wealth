import Foundation
import SwiftData

@Model
final class Expense {
    var id = UUID()
    // Always the original amount in `currency`; conversion happens at display time only.
    var amount = Decimal.zero
    var currency: String = "ARS"
    var date = Date.now
    var note: String = ""
    // "manual" | "voice"; future import sources dedupe on externalId.
    var source: String = "manual"
    var externalId: String?
    var createdAt = Date.now
    var category: Category?
    var subscription: Subscription?

    init(amount: Decimal, currency: String, date: Date = .now, note: String = "", source: String = "manual", category: Category? = nil) {
        self.amount = amount
        self.currency = currency
        self.date = date
        self.note = note
        self.source = source
        self.category = category
    }
}
