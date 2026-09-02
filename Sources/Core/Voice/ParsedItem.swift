import Foundation

// One parsed item from a dictation: something to create, an amount to change
// on an existing record, or a record to remove. Codable because a capture
// persists its items, which is what lets Restore apply them again.
struct ParsedItem: Equatable, Codable {
    enum Kind: String, Equatable, Codable {
        case expense
        case subscription
    }

    enum Action: String, Equatable, Codable {
        case create
        case update
        case delete
    }

    let kind: Kind
    // For update, amount is the new amount; for update and delete, note names
    // the existing record.
    let action: Action
    let amount: Decimal
    let currency: String
    // Merchant or description for an expense; the service name for a subscription.
    let note: String
    let categoryName: String?
    // Expense date; for a subscription, the billing anchor (start + billing day).
    let date: Date
    // Subscriptions only: "monthly" | "yearly".
    let cadence: String?
}
