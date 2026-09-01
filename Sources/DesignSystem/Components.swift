import SwiftUI

// Shared visual vocabulary from the design canvas: mono amount type, eyebrow
// labels, icon pucks, and the wrapping chip layout.
extension Font {
    static func wAmount(_ size: CGFloat) -> Font {
        // TODO(font): swap for bundled Spline Sans Mono (tasks.md); system mono is the placeholder.
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    static let wEyebrow = Font.system(size: 11, weight: .semibold, design: .monospaced)
}

struct Eyebrow: View {
    let text: String
    var color: Color = .wTextTertiary

    var body: some View {
        Text(text.uppercased())
            .font(.wEyebrow)
            .kerning(1.4)
            .foregroundStyle(color)
    }
}

struct IconPuck: View {
    let symbol: String
    var size: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.325, style: .continuous)
            .fill(Color.wCardRaised)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(Color.wTextSecondary)
            }
    }
}

// Wrapping layout for category chips (manual add) and any future chip rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 9

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.top + $0.height } ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, width: bounds.width)
        for row in rows {
            var cursor = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: cursor, y: bounds.minY + row.top),
                    proposal: ProposedViewSize(size)
                )
                cursor += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var top: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var cursor: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if cursor > 0, cursor + size.width > width {
                rows.append(current)
                current = Row(top: current.top + current.height + spacing)
                cursor = 0
            }
            current.indices.append(index)
            current.height = max(current.height, size.height)
            cursor += size.width + spacing
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
