import SwiftData
import SwiftUI

// One pill, always: a summary of the queue, never one per expense.
// States are working (amber), landing/drained (green), failure (red, sticky).
struct TickerPill: View {
    let queue: CaptureQueue
    let onTap: () -> Void

    @Query(sort: \VoiceCapture.createdAt, order: .reverse) private var captures: [VoiceCapture]
    @State private var hidden = false

    var body: some View {
        Group {
            if let state = PillState(captures: captures), !hidden {
                Button(action: onTap) {
                    HStack(spacing: 10) {
                        Image(systemName: state.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(state.tint)
                            .symbolEffect(.rotate, isActive: state.isSpinning)
                        Text(state.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.wText)
                            .lineLimit(1)
                        if state.queuedBehind > 0 {
                            Text("+\(state.queuedBehind)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.wSheet)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.wAmber, in: Capsule())
                        }
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, state.queuedBehind > 0 ? 8 : 14)
                    .frame(height: 48)
                    .background(Color.wCard, in: Capsule())
                    .overlay(Capsule().stroke(state.borderColor, lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 340)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: state.fadeKey) { await fadeIfDrained(state) }
            }
        }
        .animation(.spring(duration: 0.3), value: captures.count)
        .onChange(of: queue.lastLanded) { _, _ in hidden = false }
    }

    // Drained rests a few seconds, then fades. Failures never auto-hide.
    private func fadeIfDrained(_ state: PillState) async {
        guard state.autoHides else { return }
        try? await Task.sleep(for: .seconds(4))
        guard !Task.isCancelled else { return }
        withAnimation { hidden = true }
    }
}

// Derived purely from the persisted captures, so the pill rehydrates after a
// lock or a relaunch with no in-memory state to lose.
struct PillState: Equatable {
    let label: String
    let queuedBehind: Int
    let kind: Kind

    enum Kind { case working, landed, failed }

    init?(captures: [VoiceCapture]) {
        let active = captures.filter { $0.captureStatus == .queued || $0.captureStatus == .working }
        let failed = captures.filter { $0.captureStatus == .failed }
        let recent = captures.filter { $0.captureStatus == .applied && $0.createdAt > Date.now.addingTimeInterval(-60) }

        if let current = active.last {
            label = current.title
            queuedBehind = max(0, active.count - 1)
            kind = .working
        } else if !failed.isEmpty {
            let logged = recent.count
            label = logged > 0 ? "\(logged) logged · \(failed.count) failed" : "\(failed.count) failed"
            queuedBehind = 0
            kind = .failed
        } else if !recent.isEmpty {
            label = recent.count == 1 ? (recent[0].title) : "\(recent.count) logged"
            queuedBehind = 0
            kind = .landed
        } else {
            return nil
        }
    }

    var symbol: String {
        switch kind {
        case .working: "arrow.trianglehead.2.clockwise"
        case .landed: "checkmark.circle"
        case .failed: "xmark.circle"
        }
    }

    var tint: Color {
        switch kind {
        case .working: .wAmber
        case .landed: .wGreen
        case .failed: .wRed
        }
    }

    var borderColor: Color {
        kind == .failed ? Color.wRed.opacity(0.45) : .wBorder
    }

    var isSpinning: Bool { kind == .working }
    var autoHides: Bool { kind == .landed }
    var fadeKey: String { "\(kind)-\(label)-\(queuedBehind)" }
}
