import SwiftData
import SwiftUI

// The shared body of the add and edit sheets: currency toggle, big amount,
// category chips, date, note.
struct ExpenseForm: View {
    @Binding var draft: ExpenseDraft
    let rates: [String: Decimal]
    let base: String

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @FocusState private var amountFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            amountSection
            categorySection
            detailSection
        }
        .onAppear { amountFocused = true }
    }

    private var amountSection: some View {
        VStack(spacing: 18) {
            HStack(spacing: 0) {
                ForEach(["ARS", "USD"], id: \.self) { code in
                    Text(Money.symbol(for: code))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(draft.currency == code ? .white : Color.wTextSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background {
                            if draft.currency == code {
                                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.wAccent)
                            }
                        }
                        .onTapGesture { draft.currency = code }
                }
            }
            .padding(3)
            .background(Color.wCardRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.wBorder, lineWidth: 1))

            TextField("0", text: $draft.amountText)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .multilineTextAlignment(.center)
                .font(.wAmount(52))
                .foregroundStyle(Color.wText)
                .tint(.wAccent)

            if let approximate {
                Text("≈ \(approximate)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.wTextTertiary)
            }
        }
        .padding(.top, 36)
        .padding(.bottom, 28)
        .padding(.horizontal, 24)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Category")
            FlowLayout(spacing: 9) {
                ForEach(categories) { category in
                    CategoryChip(category: category, isSelected: draft.categoryId == category.id)
                        .onTapGesture {
                            draft.categoryId = draft.categoryId == category.id ? nil : category.id
                        }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var detailSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Date")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.wTextSecondary)
                Spacer()
                DatePicker("", selection: $draft.date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(.wAccentBright)
            }
            .padding(.vertical, 12)
            Divider().overlay(Color.wHairline)
            HStack {
                Text("Note")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.wTextSecondary)
                Spacer()
                TextField("Optional", text: $draft.note)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.wText)
                    .tint(.wAccent)
            }
            .padding(.vertical, 15)
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
    }

    private var approximate: String? {
        guard let amount = draft.amount, draft.currency != base,
              let converted = Money.convert(amount, from: draft.currency, to: base, rates: rates)
        else { return nil }
        return Money.format(converted, currency: base)
    }
}

private struct CategoryChip: View {
    let category: Category
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: category.symbol)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? Color.wAccentBright : Color.wTextSecondary)
            Text(category.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.wText : Color.wTextSecondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(isSelected ? Color.wChipSelected : Color.wCardRaised, in: Capsule())
        .overlay(Capsule().stroke(isSelected ? Color.wAccent : Color.wBorder, lineWidth: 1))
        .contentShape(.capsule)
    }
}

// Editable state for both sheets. Amount lives as text so the field can hold
// a half-typed value; `amount` is the parsed truth.
struct ExpenseDraft {
    var amountText = ""
    var currency = "ARS"
    var categoryId: UUID?
    var date = Date.now
    var note = ""

    init() {}

    init(expense: Expense) {
        amountText = Money.format(expense.amount, currency: expense.currency)
            .replacingOccurrences(of: "\(Money.symbol(for: expense.currency)) ", with: "")
        currency = expense.currency
        categoryId = expense.category?.id
        date = expense.date
        note = expense.note
    }

    var amount: Decimal? {
        // es-AR input: "." groups, "," decimals.
        let normalized = amountText
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US")), value > 0 else { return nil }
        return value
    }

    var isValid: Bool { amount != nil }
}
