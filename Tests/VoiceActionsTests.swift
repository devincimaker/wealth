import Foundation
import SwiftData
import Testing
@testable import Wealth

// Spoken updates and deletions: resolving the referenced record, applying the
// change, and reversing it on Undo.
@MainActor
struct VoiceActionsTests {
    @Test func anUpdateChangesTheNewestMatchingExpense() throws {
        let context = try makeContext()
        insertExpense(in: context, note: "Café con Juan", amount: 9800, daysAgo: 3)
        let newest = insertExpense(in: context, note: "Café Registrado", amount: 8000, daysAgo: 1)

        // Accent-insensitive: "cafe" finds both, the newest wins.
        let changes = try LedgerWriter(context: context).apply([item(.update, .expense, note: "cafe", amount: 12000)])

        #expect(newest.amount == 12000)
        #expect(changes == [.updatedExpenseAmount(id: newest.id, from: 8000, to: 12000)])
    }

    @Test func aDeleteRemovesTheExpenseAndAnAmountDisambiguates() throws {
        let context = try makeContext()
        insertExpense(in: context, note: "Súper", amount: 20000, daysAgo: 2)
        let older = insertExpense(in: context, note: "Súper", amount: 15000, daysAgo: 5)

        _ = try LedgerWriter(context: context).apply([item(.delete, .expense, note: "super", amount: 15000)])

        let remaining = try context.fetch(FetchDescriptor<Expense>())
        #expect(remaining.map(\.amount) == [Decimal(20000)])
        #expect(remaining.first?.id != older.id)
    }

    @Test func anUpdateChangesASubscriptionAmount() throws {
        let context = try makeContext()
        let netflix = insertSubscription(in: context, name: "Netflix", amount: 15999)

        _ = try LedgerWriter(context: context).apply([item(.update, .subscription, note: "netflix", amount: 18000)])

        #expect(netflix.amount == 18000)
    }

    @Test func aDeleteEndsTheSubscriptionButKeepsItsHistory() throws {
        let context = try makeContext()
        let writer = LedgerWriter(context: context)
        _ = try writer.apply([item(.create, .subscription, note: "Netflix", amount: 15999)])
        let netflix = try #require(try context.fetch(FetchDescriptor<Subscription>()).first)
        #expect(netflix.expenses?.count == 1)

        _ = try writer.apply([item(.delete, .subscription, note: "netflix", amount: 0)])

        #expect(netflix.isActive == false)
        #expect(netflix.endDate != nil)
        // The posted expense stays; only future posting stops.
        #expect(try context.fetch(FetchDescriptor<Expense>()).count == 1)
        SubscriptionPoster.postDue(in: context)
        #expect(try context.fetch(FetchDescriptor<Expense>()).count == 1)
    }

    @Test func anUnresolvedReferenceFailsTheWholeBatchAtomically() throws {
        let context = try makeContext()

        #expect(throws: VoiceError.targetNotFound("unicornio")) {
            try LedgerWriter(context: context).apply([
                self.item(.create, .expense, note: "Café", amount: 9800),
                self.item(.delete, .expense, note: "unicornio", amount: 0),
            ])
        }
        // Nothing applied: the create in the same dictation did not land.
        #expect(try context.fetch(FetchDescriptor<Expense>()).isEmpty)
    }

    @Test func undoRevertsUpdatesDeletionsAndEndings() throws {
        let context = try makeContext()
        let groceries = Category(name: "Groceries", symbol: "cart", sortOrder: 0)
        context.insert(groceries)
        let writer = LedgerWriter(context: context)
        let café = insertExpense(in: context, note: "Café", amount: 9800, daysAgo: 1)
        let súper = insertExpense(in: context, note: "Súper", amount: 20000, daysAgo: 2, category: groceries)
        let netflix = insertSubscription(in: context, name: "Netflix", amount: 15999)

        let changes = try writer.apply([
            item(.update, .expense, note: "café", amount: 12000),
            item(.delete, .expense, note: "súper", amount: 0),
            item(.delete, .subscription, note: "netflix", amount: 0),
        ])
        writer.undo(changes)

        #expect(café.amount == 9800)
        #expect(netflix.isActive == true)
        #expect(netflix.endDate == nil)
        let restored = try #require(try context.fetch(FetchDescriptor<Expense>()).first { $0.note == "Súper" })
        #expect(restored.amount == 20000)
        #expect(restored.category?.name == "Groceries")
        _ = súper
    }

    @Test func actionTitlesNameWhatHappened() {
        let update = item(.update, .expense, note: "café", amount: 12000)
        let deletion = item(.delete, .expense, note: "súper", amount: 0)
        let ending = item(.delete, .subscription, note: "Netflix", amount: 0)
        #expect(LedgerWriter.title(for: [update]) == "Updated café · \(Money.format(12000, currency: "ARS"))")
        #expect(LedgerWriter.title(for: [deletion]) == "Deleted súper")
        #expect(LedgerWriter.title(for: [ending]) == "Ended Netflix")
        #expect(LedgerWriter.title(for: [update, deletion]) == "Applied 2 changes")
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Expense.self, Category.self, Subscription.self, VoiceCapture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func item(_ action: ParsedItem.Action, _ kind: ParsedItem.Kind, note: String, amount: Decimal) -> ParsedItem {
        ParsedItem(
            kind: kind,
            action: action,
            amount: amount,
            currency: "ARS",
            note: note,
            categoryName: nil,
            date: .now,
            cadence: kind == .subscription ? "monthly" : nil
        )
    }

    @discardableResult
    private func insertExpense(
        in context: ModelContext,
        note: String,
        amount: Decimal,
        daysAgo: Int,
        category: Wealth.Category? = nil
    ) -> Expense {
        let expense = Expense(
            amount: amount,
            currency: "ARS",
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!,
            note: note,
            source: "manual",
            category: category
        )
        context.insert(expense)
        return expense
    }

    private func insertSubscription(in context: ModelContext, name: String, amount: Decimal) -> Subscription {
        let subscription = Subscription(name: name, amount: amount, currency: "ARS")
        context.insert(subscription)
        return subscription
    }
}
