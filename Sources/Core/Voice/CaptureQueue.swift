import Observation
import SwiftData
import SwiftUI
import UIKit

// The optimistic queue (HAB-134): release the mic and the expense saves on its
// own. Work is persisted per item, so locking the phone or killing the app
// never loses a capture; a background task covers the lock case mid-flight.
@MainActor
@Observable
final class CaptureQueue {
    private(set) var isWorking = false
    // Flashes green as each item lands; drives the pill's landing state.
    private(set) var lastLanded: String?

    private let context: ModelContext
    private let transcription: any TranscriptionService
    private let parsing: any ParsingService
    private var pump: Task<Void, Never>?

    init(
        context: ModelContext,
        transcription: any TranscriptionService = VoiceServices.transcription(),
        parsing: any ParsingService = VoiceServices.parsing()
    ) {
        self.context = context
        self.transcription = transcription
        self.parsing = parsing
    }

    func enqueue(audioFileName: String) {
        context.insert(VoiceCapture(audioFileName: audioFileName))
        try? context.save()
        start()
    }

    // Called on launch too: anything left queued or mid-flight resumes.
    func start() {
        guard pump == nil else { return }
        pump = Task { [weak self] in
            await self?.drain()
            self?.pump = nil
        }
    }

    func cancel(_ capture: VoiceCapture) {
        capture.captureStatus = .canceled
        capture.title = "Canceled"
        RecordingFiles.delete(capture.audioFileName)
        capture.audioFileName = nil
        try? context.save()
    }

    // Undo deletes the expense but keeps the log row, so it can be restored.
    func undo(_ capture: VoiceCapture) {
        if let expense = expense(for: capture) {
            context.delete(expense)
        }
        capture.captureStatus = .rewound
        capture.expenseId = nil
        try? context.save()
    }

    func restore(_ capture: VoiceCapture) {
        guard let amount = capture.parsedAmount else { return }
        let expense = Expense(
            amount: amount,
            currency: capture.parsedCurrency ?? "ARS",
            date: capture.parsedDate ?? capture.createdAt,
            note: capture.parsedNote ?? "",
            source: "voice",
            category: category(named: capture.parsedCategoryName)
        )
        context.insert(expense)
        capture.expenseId = expense.id
        capture.captureStatus = .applied
        try? context.save()
    }

    func retry(_ capture: VoiceCapture) {
        capture.captureStatus = .queued
        capture.failureReason = nil
        capture.title = "Logging your expense…"
        try? context.save()
        start()
    }

    func dismiss(_ capture: VoiceCapture) {
        RecordingFiles.delete(capture.audioFileName)
        context.delete(capture)
        try? context.save()
    }

    func expense(for capture: VoiceCapture) -> Expense? {
        guard let id = capture.expenseId else { return nil }
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func drain() async {
        isWorking = true
        // beginBackgroundTask keeps the drain alive when the phone locks the
        // instant the thumb lifts, which is the normal case.
        let token = UIApplication.shared.beginBackgroundTask(withName: "wealth.capture-queue")
        defer {
            isWorking = false
            if token != .invalid { UIApplication.shared.endBackgroundTask(token) }
        }
        while let next = nextPending() {
            await process(next)
        }
    }

    private func nextPending() -> VoiceCapture? {
        let queued = CaptureStatus.queued.rawValue
        let working = CaptureStatus.working.rawValue
        var descriptor = FetchDescriptor<VoiceCapture>(
            predicate: #Predicate { $0.status == queued || $0.status == working },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func process(_ capture: VoiceCapture) async {
        capture.captureStatus = .working
        try? context.save()
        guard let fileName = capture.audioFileName else {
            fail(capture, reason: "The recording is gone")
            return
        }
        do {
            // A retry after a parse failure re-uses the transcript we already
            // paid for; only a missing one goes back to Whisper.
            let transcript: String
            if let existing = capture.transcript {
                transcript = existing
            } else {
                transcript = try await transcription.transcribe(audioAt: RecordingFiles.url(for: fileName))
            }
            capture.transcript = transcript
            try? context.save()
            let names = categoryNames()
            let parsed = try await parsing.parse(
                transcript: transcript,
                categoryNames: names,
                defaultCurrency: lastUsedCurrency(),
                now: .now
            )
            apply(parsed, to: capture)
        } catch {
            fail(capture, reason: error.localizedDescription)
        }
    }

    private func apply(_ parsed: ParsedExpense, to capture: VoiceCapture) {
        let expense = Expense(
            amount: parsed.amount,
            currency: parsed.currency,
            date: parsed.date,
            note: parsed.note,
            source: "voice",
            category: category(named: parsed.categoryName)
        )
        context.insert(expense)
        capture.expenseId = expense.id
        capture.parsedAmount = parsed.amount
        capture.parsedCurrency = parsed.currency
        capture.parsedNote = parsed.note
        capture.parsedCategoryName = parsed.categoryName
        capture.parsedDate = parsed.date
        capture.captureStatus = .applied
        let label = parsed.categoryName ?? parsed.note
        capture.title = "Logged \(Money.format(parsed.amount, currency: parsed.currency)) · \(label)"
        RecordingFiles.delete(capture.audioFileName)
        capture.audioFileName = nil
        try? context.save()
        lastLanded = capture.title
    }

    private func fail(_ capture: VoiceCapture, reason: String) {
        capture.captureStatus = .failed
        capture.failureReason = reason
        // The transcript survives so Retry never re-records, and so a parse
        // failure reads differently from a network one (HAB-157).
        capture.title = reason
        try? context.save()
    }

    private func categoryNames() -> [String] {
        let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.name)
    }

    private func category(named name: String?) -> Category? {
        guard let name else { return nil }
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.name == name })
        return try? context.fetch(descriptor).first
    }

    private func lastUsedCurrency() -> String {
        var descriptor = FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor).first)?.currency ?? "ARS"
    }
}
