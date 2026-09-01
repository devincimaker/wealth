import SwiftUI

struct ExpensesHomeView: View {
    var body: some View {
        ZStack {
            Color.wBackground.ignoresSafeArea()
            Text("Expenses")
                .foregroundStyle(Color.wTextSecondary)
        }
    }
}
