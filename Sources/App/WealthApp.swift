import SwiftData
import SwiftUI

@main
@MainActor
struct WealthApp: App {
    let container: ModelContainer
    @State private var rates = RateStore()

    init() {
        // TODO(cloudkit): flip to a CloudKit-backed configuration once the
        // developer account is wired up; the schema is already CloudKit-shaped (§8).
        do {
            container = try ModelContainer(for: Expense.self, Category.self, Subscription.self, VoiceCapture.self)
        } catch {
            fatalError("Could not create model container: \(error)")
        }
        Category.seedIfNeeded(in: container.mainContext)
        #if DEBUG
        SampleData.seedIfRequested(in: container.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(rates)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
