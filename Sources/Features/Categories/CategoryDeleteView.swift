import SwiftData
import SwiftUI

// Deleting a category never silently orphans expenses: it always asks where
// they go, defaulting to "Other" when it exists.
struct CategoryDeleteView: View {
    let category: Category
    let others: [Category]
    var onDeleted: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var destination: Destination = .move
    @State private var targetId: UUID?

    private enum Destination { case move, uncategorized }

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Delete “\(category.name)”?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.wText)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.wTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            if expenseCount > 0 { options }

            VStack(spacing: 4) {
                Button(action: delete) {
                    Text("Delete category")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.wRedButton, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.wTextSecondary)
                    .frame(height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(Color.wCard)
        .presentationDetents([.height(expenseCount > 0 ? 380 : 240)])
        .presentationBackground(Color.wCard)
        .preferredColorScheme(.dark)
        .onAppear {
            targetId = others.first { $0.name == "Other" }?.id ?? others.first?.id
        }
    }

    private var options: some View {
        VStack(spacing: 0) {
            OptionRow(
                title: moveTitle,
                subtitle: "Pick any category",
                isSelected: destination == .move
            ) { destination = .move }
            if destination == .move, others.count > 1 {
                Picker("", selection: $targetId) {
                    ForEach(others) { other in
                        Text(other.name).tag(Optional(other.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(.wAccentBright)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 16)
                .padding(.bottom, 8)
            }
            Divider().overlay(Color.wHairline).padding(.horizontal, 16)
            OptionRow(
                title: "Leave uncategorized",
                subtitle: "They keep their amounts and dates",
                isSelected: destination == .uncategorized
            ) { destination = .uncategorized }
        }
        .background(Color.wBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.wHairline, lineWidth: 1))
    }

    private var expenseCount: Int {
        (category.expenses ?? []).count
    }

    private var subtitle: String {
        switch expenseCount {
        case 0: "Nothing uses this category yet."
        case 1: "1 expense uses this category. Where should it go?"
        default: "\(expenseCount) expenses use this category. Where should they go?"
        }
    }

    private var moveTitle: String {
        guard let target = others.first(where: { $0.id == targetId }) else { return "Move to another category" }
        return "Move to “\(target.name)”"
    }

    private func delete() {
        let target = destination == .move ? others.first { $0.id == targetId } : nil
        for expense in category.expenses ?? [] {
            expense.category = target
        }
        context.delete(category)
        try? context.save()
        dismiss()
        onDeleted?()
    }
}

private struct OptionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(isSelected ? Color.wAccent : Color.wTextTertiary, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                    .overlay {
                        if isSelected {
                            Circle().fill(Color.wAccent).frame(width: 10, height: 10)
                        }
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.wText)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.wTextTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
