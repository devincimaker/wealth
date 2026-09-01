import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(RateStore.self) private var rates

    @State private var queue: CaptureQueue?
    @State private var showingManualAdd = false
    @State private var showingActivity = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                ExpensesHomeView()
                    .tabItem { Label("Expenses", systemImage: "list.bullet.rectangle") }
                MonthsView()
                    .tabItem { Label("Months", systemImage: "chart.bar") }
                SubscriptionsView()
                    .tabItem { Label("Subs", systemImage: "arrow.triangle.2.circlepath") }
            }
            .tint(.wAccentBright)

            if let queue {
                CaptureDock(queue: queue, onManualAdd: { showingManualAdd = true }, onOpenActivity: { showingActivity = true })
            }
        }
        .sheet(isPresented: $showingManualAdd) { ManualAddView() }
        .sheet(isPresented: $showingActivity) {
            if let queue { ActivityLogView(queue: queue) }
        }
        .task {
            if queue == nil {
                let queue = CaptureQueue(context: context)
                self.queue = queue
                queue.start()
            }
            SubscriptionPoster.postDue(in: context)
            await rates.refresh(currencies: ["ARS"])
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            SubscriptionPoster.postDue(in: context)
            Task { await rates.refresh(currencies: ["ARS"]) }
        }
    }
}

// The "＋" action button and the ticker pill, stacked over the tab bar.
private struct CaptureDock: View {
    let queue: CaptureQueue
    let onManualAdd: () -> Void
    let onOpenActivity: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            TickerPill(queue: queue, onTap: onOpenActivity)
            ActionButton(queue: queue, onTap: onManualAdd)
        }
        // Clears the floating tab bar so the button never covers a tab.
        .padding(.bottom, 96)
    }
}
