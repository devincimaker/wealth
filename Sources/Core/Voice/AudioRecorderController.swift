import AVFoundation
import Observation

// Recordings live in Application Support until their capture lands or is
// dismissed; surviving a killed app is what makes the queue resumable.
enum RecordingFiles {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func url(for name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    static func delete(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: url(for: name))
    }
}

// AVAudioRecorder wrapper for the hold-to-speak overlay: m4a, metering for the
// waveform, hard cap so a pocketed phone can't record forever.
@MainActor
@Observable
final class AudioRecorderController {
    static let maxDuration: TimeInterval = 60

    private(set) var levels: [Float] = []
    private(set) var elapsed: TimeInterval = 0
    // The cap stops the recorder while the finger is still down; the overlay
    // watches this and finalizes as if released.
    private(set) var hitCap = false

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    func start() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
            let url = RecordingFiles.url(for: "\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record(forDuration: Self.maxDuration)
            self.recorder = recorder
            fileURL = url
            levels = []
            elapsed = 0
            hitCap = false
            Task { await meter() }
            return true
        } catch {
            return false
        }
    }

    func finish() -> URL? {
        guard let recorder, let fileURL else { return nil }
        recorder.stop()
        tearDown()
        return fileURL
    }

    func discard() {
        recorder?.stop()
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        tearDown()
    }

    private func tearDown() {
        recorder = nil
        fileURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func meter() async {
        while let recorder, recorder.isRecording {
            recorder.updateMeters()
            let decibels = recorder.averagePower(forChannel: 0)
            let level = max(0, min(1, (decibels + 50) / 50))
            levels.append(level)
            if levels.count > 24 { levels.removeFirst() }
            elapsed = recorder.currentTime
            try? await Task.sleep(for: .milliseconds(60))
        }
        if recorder != nil, elapsed >= Self.maxDuration - 0.5 {
            hitCap = true
        }
    }
}
