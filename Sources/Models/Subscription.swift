import Foundation
import SwiftData

@Model
final class Subscription {
    var id = UUID()
    var name: String = ""
    var amount = Decimal.zero
    var currency: String = "ARS"
    // "monthly" | "yearly"
    var cadence: String = "monthly"
    var billingDay: Int = 1
    // Yearly only.
    var billingMonth: Int?
    var isActive: Bool = true
    var startDate = Date.now
    var endDate: Date?
    // Drives catch-up posting on launch.
    var lastPostedDate: Date?
    var category: Category?
    @Relationship(deleteRule: .nullify, inverse: \Expense.subscription)
    var expenses: [Expense]?

    init(name: String, amount: Decimal, currency: String, cadence: String = "monthly", billingDay: Int = 1, category: Category? = nil) {
        self.name = name
        self.amount = amount
        self.currency = currency
        self.cadence = cadence
        self.billingDay = billingDay
        self.category = category
    }
}
