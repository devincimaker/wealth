import SwiftData
import SwiftUI

// Home: this month's total in base currency, then recent expenses by day.
struct ExpensesHomeView: View {
    @Environment(RateStore.self) private var rates
    @AppStorage("baseCurrency") private var baseCurrency = Money.defaultBaseCurrency
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var showingSettings = false
    @State private var editing: Expense?

    var body: some View {
        ZStack(alignment: .top) {
            Color.wBackground.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    header
                    ForEach(ExpenseAggregator.dayGroups(monthExpenses), id: \.day) { group in
                        DayHeader(
                            day: group.day,
                            total: ExpenseAggregator.total(group.expenses, base: baseCurrency, rates: rates.rates),
                            base: baseCurrency
                        )
                        ForEach(group.expenses) { expense in
                            Button { editing = expense } label: {
                                ExpenseRow(expense: expense, base: baseCurrency, rates: rates.rates)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if monthExpenses.isEmpty { emptyState }
                    // Clears the floating button and pill at the end of the list.
                    Color.clear.frame(height: 180)
                }
            }
            .scrollIndicators(.hidden)

            // The list scrolls under the dock, so it fades out rather than
            // ending abruptly behind the button.
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.wBackground.opacity(0), Color.wBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(item: $editing) { ExpenseEditView(expense: $0) }
    }

    private var monthExpenses: [Expense] {
        expenses.filter { ExpenseAggregator.isInMonth($0.date, of: .now) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow(text: ExpenseAggregator.monthHeading(for: .now))
                Spacer()
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.wTextTertiary)
                }
            }
            Text(Money.formatRounded(
                ExpenseAggregator.total(monthExpenses, base: baseCurrency, rates: rates.rates),
                currency: baseCurrency
            ))
            .font(.wAmount(42))
            .foregroundStyle(Color.wText)
            Text(ExpenseAggregator.currencyLine(monthExpenses))
                .font(.system(size: 13))
                .foregroundStyle(Color.wTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing logged this month")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.wTextSecondary)
            Text("Tap ＋ to type an expense, or hold it and say one.")
                .font(.system(size: 13))
                .foregroundStyle(Color.wTextTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
    }
}

private struct DayHeader: View {
    let day: Date
    let total: Decimal
    let base: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Eyebrow(text: ExpenseAggregator.dayHeading(for: day), color: .wTextSecondary)
            Spacer()
            Text(Money.formatRounded(total, currency: base))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.wTextTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }
}
