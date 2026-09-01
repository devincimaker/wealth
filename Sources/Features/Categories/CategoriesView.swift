import SwiftData
import SwiftUI

// Drag to reorder (this is the chip order everywhere), swipe left to delete.
// Deleting always asks where the expenses go.
struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var editing: Category?
    @State private var addingNew = false
    @State private var deleting: Category?

    var body: some View {
        ZStack {
            Color.wBackground.ignoresSafeArea()

            List {
                ForEach(categories) { category in
                    CategoryRow(category: category)
                        .listRowBackground(Color.wBackground)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .contentShape(.rect)
                        .onTapGesture { editing = category }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) { deleting = category }
                        }
                }
                .onMove(perform: reorder)

                Section {
                    AddRowButton(title: "New category") { addingNew = true }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    Text("Drag to reorder: this is the order chips appear in. Swipe left to delete; you'll choose where its expenses go.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.wTextTertiary)
                        .padding(.horizontal, 26)
                        .padding(.top, 14)
                }
                .listRowBackground(Color.wBackground)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editing) { CategoryEditView(category: $0) }
        .sheet(isPresented: $addingNew) { CategoryEditView(category: nil) }
        .sheet(item: $deleting) { category in
            CategoryDeleteView(category: category, others: categories.filter { $0.id != category.id })
        }
    }

    private func reorder(from source: IndexSet, to destination: Int) {
        var ordered = categories
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in ordered.enumerated() {
            category.sortOrder = index
        }
        try? context.save()
    }
}

private struct CategoryRow: View {
    let category: Category

    var body: some View {
        HStack(spacing: 12) {
            IconPuck(symbol: category.symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.wText)
                Text(countText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.wTextTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var countText: String {
        let count = (category.expenses ?? []).count { ExpenseAggregator.isInMonth($0.date, of: .now) }
        switch count {
        case 0: return "No expenses this month"
        case 1: return "1 expense this month"
        default: return "\(count) expenses this month"
        }
    }
}
