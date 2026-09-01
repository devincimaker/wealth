import SwiftUI

// The hold-to-speak sheet: live waveform, elapsed time, and the two things
// that matter — release saves, slide up cancels.
struct VoiceCaptureOverlay: View {
    let recorder: AudioRecorderController
    let willCancel: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.wBackground.opacity(0.2), Color.wBackground.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.wBorder)
                    .frame(width: 36, height: 5)

                HStack(spacing: 10) {
                    Circle()
                        .fill(willCancel ? Color.wTextTertiary : Color.wRed)
                        .frame(width: 8, height: 8)
                    Eyebrow(text: willCancel ? "Release to cancel" : "Listening", color: .wTextSecondary)
                    Text(timeText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.wTextTertiary)
                }

                Waveform(levels: recorder.levels)
                    .frame(height: 44)
                    .opacity(willCancel ? 0.3 : 1)

                Circle()
                    .fill(willCancel ? Color.wRedButton : Color.wAccent)
                    .frame(width: 88, height: 88)
                    .overlay {
                        Image(systemName: willCancel ? "xmark" : "mic.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .overlay {
                        Circle()
                            .stroke(Color.wAccent.opacity(0.15), lineWidth: 12)
                            .scaleEffect(1.25)
                            .opacity(willCancel ? 0 : 1)
                    }

                VStack(spacing: 6) {
                    Text(willCancel ? "Release to discard this one" : "Release to log: it saves right away")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.wText)
                    Label("Slide up to cancel", systemImage: "arrow.up")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.wTextTertiary)
                        .labelStyle(.titleAndIcon)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
            .background(Color.wCard, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .overlay(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                    .stroke(Color.wBorder, lineWidth: 1)
                    .mask(Rectangle().padding(.bottom, 40))
            }
        }
        .animation(.easeOut(duration: 0.18), value: willCancel)
    }

    private var timeText: String {
        let total = Int(recorder.elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct Waveform: View {
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(color(for: level))
                    .frame(width: 3, height: max(7, CGFloat(level) * 40))
            }
        }
        .animation(.easeOut(duration: 0.1), value: levels.count)
    }

    // Pad to a stable width so the waveform doesn't grow in from nothing.
    private var bars: [Float] {
        let padding = max(0, 24 - levels.count)
        return Array(repeating: 0.12, count: padding) + levels
    }

    private func color(for level: Float) -> Color {
        switch level {
        case ..<0.25: .wBarFaint
        case ..<0.5: .wBarDim
        case ..<0.7: .wBarMid
        default: .wAccentBright
        }
    }
}
