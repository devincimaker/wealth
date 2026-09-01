import Foundation
import SwiftData

// One item in the optimistic voice queue (HAB-134 shape): recorded audio in,
// expense out, every step persisted so a killed app resumes on next launch.
@Model
final class VoiceCapture {
    var id = UUID()
    var status: String = CaptureStatus.queued.rawValue
    // File name under RecordingFiles.directory; kept on failure so Retry
    // re-uses the same recording, deleted once the expense lands.
    var audioFileName: String?
    var transcript: String?
    // Pill and activity-log label, updated as the item advances.
    var title: String = ""
    var failureReason: String?
    var createdAt = Date.now
    // The saved expense, by id: no relationship so Undo can delete the expense
    // while this log row stays.
    var expenseId: UUID?
    // Parsed result, kept so Restore can recreate an undone expense.
    var parsedAmount: Decimal?
    var parsedCurrency: String?
    var parsedNote: String?
    var parsedCategoryName: String?
    var parsedDate: Date?

    init(audioFileName: String) {
        self.audioFileName = audioFileName
        self.title = "Logging your expense…"
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
