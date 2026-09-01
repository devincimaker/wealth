import SwiftData
import SwiftUI

// Month picker plus the per-category breakdown for the selected month.
struct MonthsView: View {
    @Environment(RateStore.self) private var rates
    @AppStorage("baseCurrency") private var baseCurrency = Money.defaultBaseCurrency
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var month = Date.now

    var body: some View {
        ZStack {
            Color.wBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                monthPicker
                totals
                Divider().overlay(Color.wHairline)
                breakdownList
            }
        }
    }

    private var monthPicker: some View {
        HStack {
            stepButton(symbol: "chevron.left", enabled: true) { step(-1) }
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.wText)
            Spacer()
            stepButton(symbol: "chevron.right", enabled: canStepForward) { step(1) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func stepButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? Color.wTextSecondary : Color.wTextTertiary.opacity(0.5))
                .frame(width: 36, height: 36)
                .background(Color.wCardRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!enabled)
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Spent this month")
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 22)
    }

    private var breakdownList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(slices, id: \.name) { slice in
                    BreakdownRow(slice: slice, base: baseCurrency)
                }
                if slices.isEmpty {
                    Text("No expenses in this month.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.wTextTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                }
                Color.clear.frame(height: 120)
            }
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
    }

    private var monthExpenses: [Expense] {
        expenses.filter { ExpenseAggregator.isInMonth($0.date, of: month) }
    }

    private var slices: [ExpenseAggregator.BreakdownSlice] {
        ExpenseAggregator.breakdown(monthExpenses, base: baseCurrency, rates: rates.rates)
    }

    private var canStepForward: Bool {
        !ExpenseAggregator.isInMonth(month, of: .now)
    }

    private func step(_ months: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: months, to: month) else { return }
        month = next
    }
}

private struct BreakdownRow: View {
    let slice: ExpenseAggregator.BreakdownSlice
    let base: String

    var body: some View {
        HStack(spacing: 12) {
            IconPuck(symbol: slice.symbol, size: 34)

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(slice.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.wText)
                    Spacer()
                    Text(Money.formatRounded(slice.total, currency: base))
                        .font(.wAmount(14))
                        .foregroundStyle(Color.wText)
                    Text(percentText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.wTextTertiary)
                        .frame(width: 32, alignment: .trailing)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.wTrack)
                        Capsule()
                            .fill(barColor)
                            .frame(width: geometry.size.width * fillFraction)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var fillFraction: CGFloat {
        CGFloat(truncating: NSDecimalNumber(decimal: slice.fill))
    }

    // The bar dims as slices get smaller, matching the canvas ramp.
    private var barColor: Color {
        switch fillFraction {
        case 0.75...: .wAccent
        case 0.45..<0.75: .wBarMid
        case 0.2..<0.45: .wBarDim
        default: .wBarFaint
        }
    }

    private var percentText: String {
        let percent = (slice.share as NSDecimalNumber).doubleValue * 100
        return "\(Int(percent.rounded()))%"
    }
}
