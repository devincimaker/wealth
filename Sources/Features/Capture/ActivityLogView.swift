import SwiftData
import SwiftUI

// The rewindable log: newest first, every capture undoable. Row actions follow
// status (Working → Cancel, Logged → Undo/Edit, Failed → Retry/Dismiss,
// Undone → Restore).
struct ActivityLogView: View {
    let queue: CaptureQueue

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VoiceCapture.createdAt, order: .reverse) private var captures: [VoiceCapture]
    @State private var editing: Expense?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Saves happen right away, on their own. Lock your phone whenever: any expense can be undone.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.wTextTertiary)
                        .padding(.bottom, 8)

                    ForEach(captures) { capture in
                        ActivityRow(capture: capture, queue: queue, onEdit: { editing = $0 })
                        Divider().overlay(Color.wHairline)
                    }

                    if captures.isEmpty {
                        Text("Nothing yet. Hold the ＋ button and say what you spent.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.wTextTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 40)
                    }
                }
                .padding(.horizontal, 24)
            }
            .background(Color.wCard)
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(.wAccentBright)
                }
            }
            .sheet(item: $editing) { ExpenseEditView(expense: $0) }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ActivityRow: View {
    let capture: VoiceCapture
    let queue: CaptureQueue
    let onEdit: (Expense) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.wCardRaised)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .opacity(capture.captureStatus == .rewound ? 0.6 : 1)

            VStack(alignment: .leading, spacing: 5) {
                Text(capture.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(capture.captureStatus == .rewound ? Color.wTextTertiary : Color.wText)
                    .strikethrough(capture.captureStatus == .rewound)
                if let transcript = capture.transcript {
                    Text("“\(transcript)”")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.wTextTertiary)
                }
                Text(capture.createdAt, format: .relative(presentation: .named))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.wTextTertiary.opacity(0.8))
                HStack(spacing: 8) {
                    ForEach(actions, id: \.title) { action in
                        Button(action.title, action: action.run)
                            .buttonStyle(ActionPillStyle(tint: action.tint))
                    }
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 8)

            Text(chipText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(tint.opacity(0.16), in: Capsule())
        }
        .padding(.vertical, 16)
    }

    private struct RowAction {
        let title: String
        var tint: Color = .wTextSecondary
        let run: () -> Void
    }

    private var actions: [RowAction] {
        switch capture.captureStatus {
        case .queued, .working:
            [RowAction(title: "Cancel") { queue.cancel(capture) }]
        case .applied:
            // Edit only when the capture made exactly one expense; a batch
            // has no single record to open, so its rows are edited in place.
            if let expense = queue.expense(for: capture) {
                [
                    RowAction(title: "Undo") { queue.undo(capture) },
                    RowAction(title: "Edit") { onEdit(expense) },
                ]
            } else {
                [RowAction(title: "Undo") { queue.undo(capture) }]
            }
        case .failed:
            [
                RowAction(title: "Retry", tint: .wAmber) { queue.retry(capture) },
                RowAction(title: "Dismiss") { queue.dismiss(capture) },
            ]
        case .rewound:
            [RowAction(title: "Restore") { queue.restore(capture) }]
        case .canceled:
            [RowAction(title: "Dismiss") { queue.dismiss(capture) }]
        }
    }

    private var symbol: String {
        switch capture.captureStatus {
        case .queued, .working: "arrow.trianglehead.2.clockwise"
        case .applied: "checkmark.circle"
        case .failed: "xmark.circle"
        case .rewound, .canceled: "arrow.uturn.backward"
        }
    }

    private var tint: Color {
        switch capture.captureStatus {
        case .queued, .working: .wAmber
        case .applied: .wGreen
        case .failed: .wRed
        case .rewound, .canceled: .wTextSecondary
        }
    }

    private var chipText: String {
        switch capture.captureStatus {
        case .queued, .working: "Working…"
        case .applied: "Logged"
        case .failed: "Failed"
        case .rewound: "Undone"
        case .canceled: "Canceled"
        }
    }
}

private struct ActionPillStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
