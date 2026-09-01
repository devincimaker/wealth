import SwiftUI

// A logged expense: original amount always, base-currency approximation only
// when it differs (conversion is at today's rate, never the rate on the date).
struct ExpenseRow: View {
    let expense: Expense
    let base: String
    let rates: [String: Decimal]

    var body: some View {
        HStack(spacing: 12) {
            IconPuck(symbol: expense.category?.symbol ?? "questionmark")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.wText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.wTextTertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.format(expense.amount, currency: expense.currency))
                    .font(.wAmount(15))
                    .foregroundStyle(Color.wText)
                if let approximate {
                    Text("≈ \(approximate)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.wTextTertiary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .contentShape(.rect)
    }

    private var title: String {
        expense.note.isEmpty ? (expense.category?.name ?? "Expense") : expense.note
    }

    private var subtitle: String {
        let category = expense.category?.name ?? "Uncategorized"
        return expense.subscription == nil ? category : "\(category) · posted automatically"
    }

    private var approximate: String? {
        guard expense.currency != base,
              let converted = Money.convert(expense.amount, from: expense.currency, to: base, rates: rates)
        else { return nil }
        return Money.formatRounded(converted, currency: base)
    }
}
