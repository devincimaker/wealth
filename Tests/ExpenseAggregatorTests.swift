import Foundation
import Testing
@testable import Wealth

@MainActor
struct ExpenseAggregatorTests {
    private let rates = ["ARS": Decimal(1485)]

    @Test func groupsByDayNewestFirst() {
        let today = Date.now
        let yesterday = today.addingTimeInterval(-86400)
        let expenses = [
            makeExpense(amount: 10, currency: "USD", date: yesterday),
            makeExpense(amount: 20, currency: "USD", date: today),
        ]
        let groups = ExpenseAggregator.dayGroups(expenses)
        #expect(groups.count == 2)
        #expect(groups[0].expenses[0].amount == 20)
        #expect(groups[1].expenses[0].amount == 10)
    }

    @Test func groupsSameDayExpensesTogether() {
        let day = Date.now
        let expenses = [
            makeExpense(amount: 10, currency: "USD", date: day),
            makeExpense(amount: 20, currency: "USD", date: day.addingTimeInterval(3600)),
        ]
        let groups = ExpenseAggregator.dayGroups(expenses)
        #expect(groups.count == 1)
        #expect(groups[0].expenses.count == 2)
    }

    @Test func totalConvertsEveryCurrencyIntoBase() {
        let expenses = [
            makeExpense(amount: 10, currency: "USD", date: .now),
            makeExpense(amount: 2970, currency: "ARS", date: .now),
        ]
        #expect(ExpenseAggregator.total(expenses, base: "USD", rates: rates) == Decimal(12))
    }

    @Test func totalSkipsAmountsWithNoKnownRate() {
        let expenses = [
            makeExpense(amount: 10, currency: "USD", date: .now),
            makeExpense(amount: 50, currency: "EUR", date: .now),
        ]
        #expect(ExpenseAggregator.total(expenses, base: "USD", rates: rates) == Decimal(10))
    }

    @Test func totalOfNothingIsZero() {
        #expect(ExpenseAggregator.total([], base: "USD", rates: rates) == Decimal.zero)
    }

    @Test func currencyLineListsOriginalTotalsPerCurrency() {
        let expenses = [
            makeExpense(amount: 412, currency: "USD", date: .now),
            makeExpense(amount: 1_295_000, currency: "ARS", date: .now),
        ]
        let line = ExpenseAggregator.currencyLine(expenses)
        #expect(line.contains("AR$ 1.295.000 in pesos"))
        #expect(line.contains("US$ 412 in dollars"))
    }

    @Test func breakdownRanksCategoriesAndComputesShares() {
        let food = Wealth.Category(name: "Food & Drink", symbol: "fork.knife", sortOrder: 0)
        let transport = Wealth.Category(name: "Transport", symbol: "car", sortOrder: 1)
        let expenses = [
            makeExpense(amount: 75, currency: "USD", date: .now, category: food),
            makeExpense(amount: 25, currency: "USD", date: .now, category: transport),
        ]
        let slices = ExpenseAggregator.breakdown(expenses, base: "USD", rates: rates)
        #expect(slices.count == 2)
        #expect(slices[0].name == "Food & Drink")
        #expect(slices[0].share == Decimal(string: "0.75")!)
        #expect(slices[1].share == Decimal(string: "0.25")!)
        // The largest slice fills the bar; others are relative to it (25/75).
        #expect(slices[0].fill == Decimal(1))
        #expect(slices[1].fill > Decimal(string: "0.33")! && slices[1].fill < Decimal(string: "0.34")!)
    }

    @Test func breakdownLabelsExpensesWithNoCategory() {
        let expenses = [makeExpense(amount: 10, currency: "USD", date: .now)]
        let slices = ExpenseAggregator.breakdown(expenses, base: "USD", rates: rates)
        #expect(slices.count == 1)
        #expect(slices[0].name == "Uncategorized")
    }

    @Test func breakdownOfNothingIsEmpty() {
        #expect(ExpenseAggregator.breakdown([], base: "USD", rates: rates).isEmpty)
    }

    @Test func monthMembershipComparesMonthAndYear() {
        let calendar = Calendar(identifier: .gregorian)
        let september = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15))!
        let alsoSeptember = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let october = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let lastYear = calendar.date(from: DateComponents(year: 2025, month: 9, day: 15))!
        #expect(ExpenseAggregator.isInMonth(alsoSeptember, of: september, calendar: calendar))
        #expect(!ExpenseAggregator.isInMonth(october, of: september, calendar: calendar))
        #expect(!ExpenseAggregator.isInMonth(lastYear, of: september, calendar: calendar))
    }

    @Test func dayHeadingNamesTodayAndYesterday() {
        let now = Date.now
        #expect(ExpenseAggregator.dayHeading(for: now, now: now).hasPrefix("TODAY · "))
        let yesterday = now.addingTimeInterval(-86400)
        #expect(ExpenseAggregator.dayHeading(for: yesterday, now: now).hasPrefix("YESTERDAY · "))
    }

    @Test func dayHeadingUsesWeekdayAndMonthForOlderDays() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let friday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 28))!
        let heading = ExpenseAggregator.dayHeading(for: friday, now: now, calendar: calendar)
        #expect(heading.contains("AUG"))
        #expect(!heading.contains("TODAY"))
    }

    private func makeExpense(amount: Decimal, currency: String, date: Date, category: Wealth.Category? = nil) -> Expense {
        Expense(amount: amount, currency: currency, date: date, category: category)
    }
}
