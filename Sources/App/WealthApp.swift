import SwiftData
import SwiftUI

@main
@MainActor
struct WealthApp: App {
    let container: ModelContainer

    init() {
        // TODO(cloudkit): flip to a CloudKit-backed configuration once the
        // developer account is wired up; the schema is already CloudKit-shaped (§8).
        do {
            container = try ModelContainer(for: Expense.self, Category.self, Subscription.self)
        } catch {
            fatalError("Could not create model container: \(error)")
        }
        Category.seedIfNeeded(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
