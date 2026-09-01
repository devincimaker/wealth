import SwiftData
import SwiftUI

struct ManualAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(RateStore.self) private var rates
    @AppStorage("baseCurrency") private var baseCurrency = Money.defaultBaseCurrency
    @AppStorage("lastUsedCurrency") private var lastUsedCurrency = "ARS"
    @State private var draft = ExpenseDraft()

    var body: some View {
        SheetScaffold(title: "New expense") {
            ExpenseForm(draft: $draft, rates: rates.rates, base: baseCurrency)
        } footer: {
            PrimaryButton(title: "Save expense", isEnabled: draft.isValid, action: save)
        }
        .onAppear { draft.currency = lastUsedCurrency }
    }

    private func save() {
        guard let amount = draft.amount else { return }
        let expense = Expense(
            amount: amount,
            currency: draft.currency,
            date: draft.date,
            note: draft.note,
            source: "manual",
            category: draft.categoryId.flatMap { findCategory($0) }
        )
        context.insert(expense)
        try? context.save()
        lastUsedCurrency = draft.currency
        dismiss()
    }

    private func findCategory(_ id: UUID) -> Category? {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}

struct ExpenseEditView: View {
    let expense: Expense

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(RateStore.self) private var rates
    @AppStorage("baseCurrency") private var baseCurrency = Money.defaultBaseCurrency
    @State private var draft = ExpenseDraft()
    @State private var confirmingDelete = false

    var body: some View {
        SheetScaffold(title: "Edit expense") {
            ExpenseForm(draft: $draft, rates: rates.rates, base: baseCurrency)
        } footer: {
            VStack(spacing: 12) {
                PrimaryButton(title: "Save", isEnabled: draft.isValid, action: save)
                Button("Delete expense") { confirmingDelete = true }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.wRed)
                    .frame(height: 40)
            }
        }
        .onAppear { draft = ExpenseDraft(expense: expense) }
        .confirmationDialog("Delete this expense?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(expense)
                try? context.save()
                dismiss()
            }
        }
    }

    private func save() {
        guard let amount = draft.amount else { return }
        expense.amount = amount
        expense.currency = draft.currency
        expense.date = draft.date
        expense.note = draft.note
        expense.category = draft.categoryId.flatMap { id in
            let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })
            return try? context.fetch(descriptor).first
        }
        try? context.save()
        dismiss()
    }
}
