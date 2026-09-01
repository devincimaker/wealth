import Foundation
import Testing
@testable import Wealth

// Amount entry follows es-AR conventions: "." groups thousands, "," is decimal.
@MainActor
struct ExpenseDraftTests {
    @Test func readsGroupedIntegerInput() {
        var draft = ExpenseDraft()
        draft.amountText = "24.900"
        #expect(draft.amount == Decimal(24900))
    }

    @Test func readsCommaDecimals() {
        var draft = ExpenseDraft()
        draft.amountText = "16,77"
        #expect(draft.amount == Decimal(string: "16.77")!)
    }

    @Test func readsGroupedAndFractionalTogether() {
        var draft = ExpenseDraft()
        draft.amountText = "1.295.000,50"
        #expect(draft.amount == Decimal(string: "1295000.5")!)
    }

    @Test func emptyAndZeroAmountsAreInvalid() {
        var draft = ExpenseDraft()
        #expect(draft.amount == nil)
        #expect(!draft.isValid)
        draft.amountText = "0"
        #expect(draft.amount == nil)
        draft.amountText = "abc"
        #expect(draft.amount == nil)
    }

    @Test func loadingAnExpenseRoundTripsItsAmount() {
        let expense = Expense(amount: Decimal(24900), currency: "ARS", note: "Farmacia")
        let draft = ExpenseDraft(expense: expense)
        #expect(draft.amountText == "24.900")
        #expect(draft.amount == Decimal(24900))
        #expect(draft.currency == "ARS")
        #expect(draft.note == "Farmacia")
    }

    @Test func loadingAFractionalExpenseRoundTrips() {
        let expense = Expense(amount: Decimal(string: "2.99")!, currency: "USD")
        let draft = ExpenseDraft(expense: expense)
        #expect(draft.amountText == "2,99")
        #expect(draft.amount == Decimal(string: "2.99")!)
    }
}
