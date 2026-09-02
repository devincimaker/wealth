import Foundation

// One reversible change a voice capture applied to the ledger. The capture
// persists its list as JSON, which is what lets Undo reverse exactly what
// happened and Restore bring it back.
enum AppliedChange: Codable, Equatable {
    case createdExpense(id: UUID)
    case createdSubscription(id: UUID)
    case updatedExpenseAmount(id: UUID, from: Decimal, to: Decimal)
    case updatedSubscriptionAmount(id: UUID, from: Decimal, to: Decimal)
    case deletedExpense(ExpenseSnapshot)
    case endedSubscription(id: UUID, previousEndDate: Date?)
}

// Enough of a deleted expense to bring it back on Undo. The subscription link
// is deliberately not kept: a posted expense comes back as a plain record.
struct ExpenseSnapshot: Codable, Equatable {
    let amount: Decimal
    let currency: String
    let date: Date
    let note: String
    let categoryName: String?
    let source: String
}
