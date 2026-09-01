import SwiftUI

// One button, two gestures (SPECS §quick add): tap opens the manual sheet,
// a ~400 ms hold starts recording, release saves, sliding up cancels.
struct ActionButton: View {
    let queue: CaptureQueue
    let onTap: () -> Void

    @State private var recorder = AudioRecorderController()
    @State private var isRecording = false
    @State private var willCancel = false
    @State private var holdTask: Task<Void, Never>?

    private static let holdDelay = Duration.milliseconds(400)
    private static let cancelDistance: CGFloat = 80

    var body: some View {
        Circle()
            .fill(willCancel ? Color.wRedButton : Color.wAccent)
            .frame(width: 64, height: 64)
            .shadow(color: Color.wAccent.opacity(0.35), radius: 12, y: 8)
            .overlay {
                Image(systemName: isRecording ? "mic.fill" : "plus")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isRecording ? 1.08 : 1)
            .animation(.spring(duration: 0.25), value: isRecording)
            .animation(.easeOut(duration: 0.15), value: willCancel)
            .gesture(pressGesture)
            .accessibilityLabel("Add expense")
            .accessibilityHint("Tap to type it, hold to speak it")
            .fullScreenCover(isPresented: $isRecording) {
                VoiceCaptureOverlay(recorder: recorder, willCancel: willCancel)
                    .presentationBackground(.clear)
            }
            .onChange(of: recorder.hitCap) { _, capped in
                if capped, isRecording { finish(cancel: false) }
            }
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if holdTask == nil, !isRecording {
                    holdTask = Task { await beginHold() }
                }
                if isRecording {
                    willCancel = value.translation.height < -Self.cancelDistance
                }
            }
            .onEnded { _ in
                holdTask?.cancel()
                holdTask = nil
                if isRecording {
                    finish(cancel: willCancel)
                } else {
                    onTap()
                }
            }
    }

    private func beginHold() async {
        try? await Task.sleep(for: Self.holdDelay)
        guard !Task.isCancelled else { return }
        guard await recorder.start() else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isRecording = true
    }

    private func finish(cancel: Bool) {
        isRecording = false
        willCancel = false
        if cancel {
            recorder.discard()
            return
        }
        guard let url = recorder.finish() else { return }
        queue.enqueue(audioFileName: url.lastPathComponent)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
