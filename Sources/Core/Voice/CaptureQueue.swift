import Observation
import SwiftData
import SwiftUI
import UIKit

// The optimistic queue (HAB-134): release the mic and the records save on
// their own. Work is persisted per item, so locking the phone or killing the
// app never loses a capture; a background task covers the lock case mid-flight.
@MainActor
@Observable
final class CaptureQueue {
    private(set) var isWorking = false
    // Flashes green as each item lands; drives the pill's landing state.
    private(set) var lastLanded: String?

    private let context: ModelContext
    private let assistant: any AssistantService
    private var pump: Task<Void, Never>?

    init(context: ModelContext, assistant: any AssistantService = VoiceServices.assistant()) {
        self.context = context
        self.assistant = assistant
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

    // Undo reverses everything the capture did but keeps the log row, so it
    // can be restored.
    func undo(_ capture: VoiceCapture) {
        LedgerWriter(context: context).undo(changes(for: capture))
        capture.captureStatus = .rewound
        capture.appliedChangesData = nil
        try? context.save()
    }

    // Re-applies the parsed items; a reference that no longer resolves turns
    // the row into a visible failure instead of silently doing nothing.
    func restore(_ capture: VoiceCapture) {
        guard let data = capture.parsedItemsData,
              let items = try? JSONDecoder().decode([ParsedItem].self, from: data),
              !items.isEmpty
        else { return }
        do {
            let applied = try LedgerWriter(context: context).apply(items)
            capture.appliedChangesData = try? JSONEncoder().encode(applied)
            capture.captureStatus = .applied
            try? context.save()
        } catch {
            fail(capture, reason: error.localizedDescription)
        }
    }

    func retry(_ capture: VoiceCapture) {
        capture.captureStatus = .queued
        capture.failureReason = nil
        capture.title = "Logging what you said…"
        try? context.save()
        start()
    }

    func dismiss(_ capture: VoiceCapture) {
        RecordingFiles.delete(capture.audioFileName)
        context.delete(capture)
        try? context.save()
    }

    // The one expense a capture created, for Edit; anything else has no
    // single record to open, so the action stays hidden.
    func expense(for capture: VoiceCapture) -> Expense? {
        let changes = changes(for: capture)
        guard changes.count == 1, case .createdExpense(let id) = changes[0] else { return nil }
        return LedgerWriter(context: context).expense(id: id)
    }

    private func changes(for capture: VoiceCapture) -> [AppliedChange] {
        guard let data = capture.appliedChangesData else { return [] }
        return (try? JSONDecoder().decode([AppliedChange].self, from: data)) ?? []
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
        // A retry after a parse failure re-uses the transcript we already
        // paid for; only a capture with neither is truly gone.
        let audioURL = capture.audioFileName.map { RecordingFiles.url(for: $0) }
        guard audioURL != nil || capture.transcript != nil else {
            fail(capture, reason: "The recording is gone")
            return
        }
        do {
            let reply = try await assistant.parse(
                audioURL: audioURL,
                transcript: capture.transcript,
                context: parseContext()
            )
            if !reply.transcript.isEmpty { capture.transcript = reply.transcript }
            try? context.save()
            guard !reply.items.isEmpty else {
                fail(capture, reason: VoiceError.noAmount.localizedDescription ?? "")
                return
            }
            apply(reply.items, to: capture)
        } catch {
            fail(capture, reason: error.localizedDescription)
        }
    }

    // What the server shows the model: the ledger as it stands, so spoken
    // references resolve against real records.
    private func parseContext() -> ParseContext {
        var expenses = FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        expenses.fetchLimit = 30
        var subscriptions = FetchDescriptor<Subscription>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        subscriptions.predicate = #Predicate { $0.isActive }
        let formatter = ISO8601DateFormatter.dateOnly
        return ParseContext(
            today: formatter.string(from: .now),
            defaultCurrency: lastUsedCurrency(),
            categories: categoryNames(),
            subscriptions: ((try? context.fetch(subscriptions)) ?? []).map {
                ParseContext.SubscriptionRef(name: $0.name, amount: $0.amount, currency: $0.currency, cadence: $0.cadence)
            },
            recentExpenses: ((try? context.fetch(expenses)) ?? []).map {
                ParseContext.ExpenseRef(note: $0.note, amount: $0.amount, currency: $0.currency, date: formatter.string(from: $0.date))
            }
        )
    }

    func apply(_ items: [ParsedItem], to capture: VoiceCapture) {
        do {
            let applied = try LedgerWriter(context: context).apply(items)
            capture.appliedChangesData = try? JSONEncoder().encode(applied)
            capture.parsedItemsData = try? JSONEncoder().encode(items)
            capture.captureStatus = .applied
            capture.title = LedgerWriter.title(for: items)
            RecordingFiles.delete(capture.audioFileName)
            capture.audioFileName = nil
            try? context.save()
            lastLanded = capture.title
        } catch {
            fail(capture, reason: error.localizedDescription)
        }
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

    private func lastUsedCurrency() -> String {
        var descriptor = FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor).first)?.currency ?? "ARS"
    }
}
