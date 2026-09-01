import SwiftData
import SwiftUI

// One sheet for create and edit: name plus a fixed icon set.
struct CategoryEditView: View {
    let category: Category?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var name = ""
    @State private var symbol = CategoryIcons.all[0]
    @State private var deleting = false

    var body: some View {
        SheetScaffold(title: category == nil ? "New category" : "Edit category") {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Name")
                    TextField("Groceries", text: $name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.wText)
                        .tint(.wAccent)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.wCardRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.wBorder, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Icon")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                        ForEach(CategoryIcons.all, id: \.self) { icon in
                            IconCell(symbol: icon, isSelected: icon == symbol)
                                .onTapGesture { symbol = icon }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
        } footer: {
            VStack(spacing: 12) {
                PrimaryButton(title: "Save", isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty, action: save)
                if category != nil {
                    Button("Delete category") { deleting = true }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.wRed)
                        .frame(height: 40)
                }
            }
        }
        .onAppear {
            guard let category else { return }
            name = category.name
            symbol = category.symbol
        }
        .sheet(isPresented: $deleting) {
            if let category {
                CategoryDeleteView(category: category, others: categories.filter { $0.id != category.id }) {
                    dismiss()
                }
            }
        }
    }

    private func save() {
        if let category {
            category.name = name
            category.symbol = symbol
        } else {
            let order = (categories.map(\.sortOrder).max() ?? -1) + 1
            context.insert(Category(name: name, symbol: symbol, sortOrder: order))
        }
        try? context.save()
        dismiss()
    }
}

private struct IconCell: View {
    let symbol: String
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isSelected ? Color.wChipSelected : Color.wCardRaised)
            .frame(height: 52)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.wAccentBright : Color.wTextSecondary)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.wAccent : Color.wBorder, lineWidth: 1)
            }
            .shadow(color: isSelected ? Color.wAccent.opacity(0.25) : .clear, radius: 3)
    }
}

// The fixed icon set offered when naming a category.
enum CategoryIcons {
    static let all = [
        "fork.knife", "cup.and.saucer", "cart", "car", "house", "arrow.triangle.2.circlepath",
        "heart", "film", "airplane", "gift", "book", "music.note",
        "iphone", "dumbbell", "graduationcap", "chart.bar", "calendar", "ellipsis",
    ]
}
