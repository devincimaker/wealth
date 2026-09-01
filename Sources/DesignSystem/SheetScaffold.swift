import SwiftUI

// The half-sheet chrome shared by every sheet in the app: grabber, title with
// a close puck, scrolling body, pinned footer.
struct SheetScaffold<Content: View, Footer: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.wBorder)
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 2)

            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.wText)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.wTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.wControl, in: Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)

            ScrollView {
                content()
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            footer()
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 40)
        }
        .background(Color.wSheet)
        .preferredColorScheme(.dark)
    }
}

struct PrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.wAccent.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// Dashed "New …" row that ends the categories and subscriptions lists.
struct AddRowButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Color.wTextSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.wBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
        }
        .buttonStyle(.plain)
    }
}
