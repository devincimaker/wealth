import Foundation
import SwiftData
import Testing
@testable import Wealth

// Applying, undoing, and restoring parsed batches against an in-memory store.
@MainActor
struct CaptureQueueTests {
    @Test func aBatchCreatesOneRecordPerItem() throws {
        let context = try makeContext()
        let queue = makeQueue(context: context)
        let capture = insertCapture(in: context)

        queue.apply([expenseItem(note: "Café", amount: 9800), expenseItem(note: "Taxi", amount: 7000), subscriptionItem()], to: capture)

        #expect(capture.captureStatus == .applied)
        #expect(try context.fetch(FetchDescriptor<Subscription>()).count == 1)
        let voiceExpenses = try context.fetch(FetchDescriptor<Expense>()).filter { $0.source == "voice" }
        #expect(Set(voiceExpenses.map(\.note)) == Set(["Café", "Taxi"]))
    }

    @Test func aSpokenSubscriptionPostsItsFirstCycle() throws {
        let context = try makeContext()
        let queue = makeQueue(context: context)
        let capture = insertCapture(in: context)
        let now = Date.now

        queue.apply([subscriptionItem(date: now)], to: capture)

        let subscription = try #require(try context.fetch(FetchDescriptor<Subscription>()).first)
        #expect(subscription.name == "Claude Pro")
        #expect(subscription.billingDay == Calendar.current.component(.day, from: now))
        // The cycle just spoken about is already paid, so it posts right away.
        let posted = try #require(subscription.expenses?.first)
        #expect(posted.source == "subscription")
        #expect(posted.amount == Decimal(200))
    }

    @Test func aYearlySubscriptionAnchorsToItsMonth() throws {
        let context = try makeContext()
        let queue = makeQueue(context: context)
        let capture = insertCapture(in: context)
        let now = Date.now

        queue.apply([subscriptionItem(cadence: "yearly", date: now)], to: capture)

        let subscription = try #require(try context.fetch(FetchDescriptor<Subscription>()).first)
        #expect(subscription.cadence == "yearly")
        #expect(subscription.billingMonth == Calendar.current.component(.month, from: now))
    }

    @Test func undoRemovesEveryRecordButKeepsTheRow() throws {
        let context = try makeContext()
        let queue = makeQueue(context: context)
        let capture = insertCapture(in: context)
        queue.apply([expenseItem(note: "Café", amount: 9800), subscriptionItem()], to: capture)

        queue.undo(capture)

        #expect(capture.captureStatus == .rewound)
        #expect(capture.appliedChangesData == nil)
        // The subscription's posted expense goes with it.
        #expect(try context.fetch(FetchDescriptor<Expense>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Subscription>()).isEmpty)
    }

    @Test func restoreRecreatesTheWholeBatch() throws {
        let context = try makeContext()
        let queue = makeQueue(context: context)
        let capture = insertCapture(in: context)
        queue.apply([expenseItem(note: "Café", amount: 9800), subscriptionItem()], to: capture)
        queue.undo(capture)

        queue.restore(capture)

        #expect(capture.captureStatus == .applied)
        #expect(try context.fetch(FetchDescriptor<Expense>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<Subscription>()).count == 1)
    }

    @Test func editOnlyTargetsASingleExpenseCapture() throws {
        let context = try makeContext()
        let queue = makeQueue(context: context)
        let single = insertCapture(in: context)
        let batch = insertCapture(in: context)
        queue.apply([expenseItem(note: "Café", amount: 9800)], to: single)
        queue.apply([expenseItem(note: "Taxi", amount: 7000), subscriptionItem()], to: batch)

        #expect(queue.expense(for: single)?.note == "Café")
        #expect(queue.expense(for: batch) == nil)
    }

    @Test func titlesNameSingleItemsAndCountBatches() {
        let café = expenseItem(note: "Café", amount: 9800)
        let taxi = expenseItem(note: "Taxi", amount: 7000)
        let claude = subscriptionItem()
        #expect(LedgerWriter.title(for: [café]) == "Logged \(Money.format(9800, currency: "ARS")) · Café")
        #expect(LedgerWriter.title(for: [claude]) == "Added Claude Pro · \(Money.format(200, currency: "USD")) monthly")
        #expect(LedgerWriter.title(for: [café, taxi]) == "Logged 2 items · \(Money.format(16800, currency: "ARS"))")
        // Mixed currencies have no honest total, so the count stands alone.
        #expect(LedgerWriter.title(for: [café, claude]) == "Logged 2 items")
    }

    @Test func aCategoryNameBecomesTheRealCategory() throws {
        let context = try makeContext()
        context.insert(Category(name: "Food & Drink", symbol: "fork.knife", sortOrder: 0))
        let queue = makeQueue(context: context)
        let capture = insertCapture(in: context)

        queue.apply([expenseItem(note: "Café", amount: 9800, categoryName: "Food & Drink")], to: capture)

        let expense = try #require(queue.expense(for: capture))
        #expect(expense.category?.name == "Food & Drink")
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Expense.self, Category.self, Subscription.self, VoiceCapture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeQueue(context: ModelContext) -> CaptureQueue {
        CaptureQueue(context: context, assistant: MockAssistantService())
    }

    private func insertCapture(in context: ModelContext) -> VoiceCapture {
        let capture = VoiceCapture(audioFileName: "test.m4a")
        context.insert(capture)
        return capture
    }

    private func expenseItem(note: String, amount: Decimal, categoryName: String? = nil) -> ParsedItem {
        ParsedItem(
            kind: .expense, action: .create, amount: amount, currency: "ARS",
            note: note, categoryName: categoryName, date: .now, cadence: nil
        )
    }

    private func subscriptionItem(cadence: String = "monthly", date: Date = .now) -> ParsedItem {
        ParsedItem(
            kind: .subscription, action: .create, amount: 200, currency: "USD",
            note: "Claude Pro", categoryName: nil, date: date, cadence: cadence
        )
    }
}
