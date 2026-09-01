import Foundation

// Pure grouping and totaling logic behind the home list, month view, and
// subscriptions burn card. Everything here is unit-tested; views only render.
enum ExpenseAggregator {
    struct BreakdownSlice: Equatable {
        let name: String
        let symbol: String
        let total: Decimal
        // Share of the month total (0...1) and fill relative to the largest slice.
        let share: Decimal
        let fill: Decimal
    }

    static func dayGroups(_ expenses: [Expense], calendar: Calendar = .current) -> [(day: Date, expenses: [Expense])] {
        let grouped = Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day, default: []].sorted { $0.createdAt > $1.createdAt })
        }
    }

    // Sum in `base`, skipping amounts with no known rate (only possible before
    // the first successful rate fetch; the cache makes this transient).
    static func total(_ expenses: [Expense], base: String, rates: [String: Decimal]) -> Decimal {
        expenses.reduce(Decimal.zero) { sum, expense in
            sum + (Money.convert(expense.amount, from: expense.currency, to: base, rates: rates) ?? 0)
        }
    }

    // "US$ 412 in dollars  +  AR$ 1.295.000 in pesos" under the big total.
    static func currencyLine(_ expenses: [Expense]) -> String {
        let totals = Dictionary(grouping: expenses, by: \.currency)
            .mapValues { $0.reduce(Decimal.zero) { $0 + $1.amount } }
        let parts = totals.keys.sorted().compactMap { currency -> String? in
            guard let total = totals[currency], total > 0 else { return nil }
            return "\(Money.formatRounded(total, currency: currency)) \(currencyWord(currency))"
        }
        return parts.joined(separator: "  +  ")
    }

    static func breakdown(_ expenses: [Expense], base: String, rates: [String: Decimal]) -> [BreakdownSlice] {
        let monthTotal = total(expenses, base: base, rates: rates)
        guard monthTotal > 0 else { return [] }
        let grouped = Dictionary(grouping: expenses) { $0.category?.name ?? "Uncategorized" }
        let unsorted = grouped.map { name, group in
            let symbol = group.first?.category?.symbol ?? "questionmark"
            return BreakdownSlice(
                name: name,
                symbol: symbol,
                total: total(group, base: base, rates: rates),
                share: 0,
                fill: 0
            )
        }
        let ranked = unsorted.sorted { $0.total > $1.total }
        guard let top = ranked.first, top.total > 0 else { return [] }
        return ranked.map { slice in
            BreakdownSlice(
                name: slice.name,
                symbol: slice.symbol,
                total: slice.total,
                share: slice.total / monthTotal,
                fill: slice.total / top.total
            )
        }
    }

    static func isInMonth(_ date: Date, of reference: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, equalTo: reference, toGranularity: .month)
    }

    // "TODAY · MON 1" / "YESTERDAY · SUN 31" / "FRI 29 AUG"
    static func dayHeading(for day: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        if calendar.isDate(day, inSameDayAs: now) {
            formatter.dateFormat = "EEE d"
            return "TODAY · \(formatter.string(from: day).uppercased())"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(day, inSameDayAs: yesterday) {
            formatter.dateFormat = "EEE d"
            return "YESTERDAY · \(formatter.string(from: day).uppercased())"
        }
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: day).uppercased()
    }

    // "SEPTEMBER 2026"
    static func monthHeading(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).uppercased()
    }

    private static func currencyWord(_ code: String) -> String {
        switch code {
        case "USD": "in dollars"
        case "ARS": "in pesos"
        default: code
        }
    }
}
