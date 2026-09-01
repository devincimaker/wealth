import Foundation
import SwiftData

@Model
final class Category {
    var id = UUID()
    var name: String = ""
    // SF Symbol name shown in pucks and chips.
    var symbol: String = "circle"
    // List order here is chip order everywhere (manual add, breakdowns).
    var sortOrder: Int = 0
    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense]?

    init(name: String, symbol: String, sortOrder: Int) {
        self.name = name
        self.symbol = symbol
        self.sortOrder = sortOrder
    }

    static func seedIfNeeded(in context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard count == 0 else { return }
        let defaults: [(String, String)] = [
            ("Food & Drink", "fork.knife"),
            ("Groceries", "cart"),
            ("Transport", "car"),
            ("Housing", "house"),
            ("Subscriptions", "arrow.triangle.2.circlepath"),
            ("Health", "heart"),
            ("Entertainment", "film"),
            ("Travel", "airplane"),
            ("Other", "ellipsis"),
        ]
        for (index, item) in defaults.enumerated() {
            context.insert(Category(name: item.0, symbol: item.1, sortOrder: index))
        }
        try? context.save()
    }
}
