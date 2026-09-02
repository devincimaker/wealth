import Foundation
import SwiftData

// One item in the optimistic voice queue (HAB-134 shape): recorded audio in,
// any number of expenses and subscriptions out, every step persisted so a
// killed app resumes on next launch.
@Model
final class VoiceCapture {
    var id = UUID()
    var status: String = CaptureStatus.queued.rawValue
    // File name under RecordingFiles.directory; kept on failure so Retry
    // re-uses the same recording, deleted once the records land.
    var audioFileName: String?
    var transcript: String?
    // Pill and activity-log label, updated as the item advances.
    var title: String = ""
    var failureReason: String?
    var createdAt = Date.now
    // JSON-encoded [AppliedChange]: everything this capture did to the
    // ledger, kept so Undo can reverse it while this log row stays.
    var appliedChangesData: Data?
    // JSON-encoded [ParsedItem], kept so Restore can apply the capture again.
    var parsedItemsData: Data?

    init(audioFileName: String) {
        self.audioFileName = audioFileName
        self.title = "Logging what you said…"
    }

    var captureStatus: CaptureStatus {
        get { CaptureStatus(rawValue: status) ?? .failed }
        set { status = newValue.rawValue }
    }
}

enum CaptureStatus: String {
    case queued
    case working
    case applied
    case failed
    case rewound
    case canceled
}
