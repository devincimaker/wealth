import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ExpensesHomeView()
                .tabItem { Label("Expenses", systemImage: "list.bullet.rectangle") }
            MonthsView()
                .tabItem { Label("Months", systemImage: "chart.bar") }
            SubscriptionsView()
                .tabItem { Label("Subs", systemImage: "arrow.triangle.2.circlepath") }
        }
        .tint(.wAccentBright)
    }
}
