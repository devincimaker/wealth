import Foundation
import SwiftData

// The write side of the capture queue: applies parsed voice items to the
// ledger and reverses them on Undo. Updates and deletions reference existing
// records by spoken name; every reference must resolve before anything
// mutates, so a bad one fails the whole capture instead of applying half a
// dictation.
@MainActor
struct LedgerWriter {
    let context: ModelContext

    func apply(_ items: [ParsedItem]) throws -> [AppliedChange] {
        let targets = try resolveTargets(for: items)
        let changes = zip(items, targets).map { applyOne($0, to: $1) }
        let createdSubscription = changes.contains {
            if case .createdSubscription = $0 { return true } else { return false }
        }
        // A new subscription starts on its parsed date, so the cycle just
        // spoken about posts right away through the normal poster.
        if createdSubscription { SubscriptionPoster.postDue(in: context) }
        return changes
    }

    func undo(_ changes: [AppliedChange]) {
        for change in changes.reversed() {
            switch change {
            case .createdExpense(let id):
                if let expense = expense(id: id) { context.delete(expense) }
            case .createdSubscription(let id):
                // The subscription takes the expenses it posted with it.
                if let subscription = subscription(id: id) {
                    for posted in subscription.expenses ?? [] { context.delete(posted) }
                    context.delete(subscription)
                }
            case .updatedExpenseAmount(let id, let from, _):
                expense(id: id)?.amount = from
            case .updatedSubscriptionAmount(let id, let from, _):
                subscription(id: id)?.amount = from
            case .deletedExpense(let snapshot):
                context.insert(Expense(
                    amount: snapshot.amount,
                    currency: snapshot.currency,
                    date: snapshot.date,
                    note: snapshot.note,
                    source: snapshot.source,
                    category: category(named: snapshot.categoryName)
                ))
            case .endedSubscription(let id, let previousEndDate):
                if let subscription = subscription(id: id) {
                    subscription.isActive = true
                    subscription.endDate = previousEndDate
                }
            }
        }
    }

    // Ticker-pill and activity-log label: a single item names itself, a batch
    // of new spends counts and totals when one currency covers everything.
    static func title(for items: [ParsedItem]) -> String {
        if items.count == 1, let item = items.first { return singleTitle(item) }
        guard items.allSatisfy({ $0.action == .create }) else { return "Applied \(items.count) changes" }
        let currencies = Set(items.map(\.currency))
        guard let currency = currencies.first, currencies.count == 1 else {
            return "Logged \(items.count) items"
        }
        let total = items.reduce(Decimal.zero) { $0 + $1.amount }
        return "Logged \(items.count) items · \(Money.format(total, currency: currency))"
    }

    // Spoken references match saved names ignoring case and accents, in either
    // containment direction ("cafe" finds "Café con Juan"). Public for tests.
    static func nameMatches(_ target: String, _ candidate: String) -> Bool {
        let target = fold(target)
        let candidate = fold(candidate)
        guard !target.isEmpty, !candidate.isEmpty else { return false }
        return candidate.contains(target) || target.contains(candidate)
    }

    private static func fold(_ string: String) -> String {
        string
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private enum Target {
        case expense(Expense)
        case subscription(Subscription)
    }

    private func resolveTargets(for items: [ParsedItem]) throws -> [Target?] {
        try items.map { item in
            guard item.action != .create else { return nil }
            switch item.kind {
            case .expense:
                let hint = item.action == .delete ? item.amount : 0
                guard let match = latestExpense(matching: item.note, amountHint: hint) else {
                    throw VoiceError.targetNotFound(item.note)
                }
                return .expense(match)
            case .subscription:
                guard let match = activeSubscription(matching: item.note) else {
                    throw VoiceError.targetNotFound(item.note)
                }
                return .subscription(match)
            }
        }
    }

    private func applyOne(_ item: ParsedItem, to target: Target?) -> AppliedChange {
        switch (item.action, target) {
        case (.create, _):
            return item.kind == .expense ? createExpense(item) : createSubscription(item)
        case (.update, .expense(let expense)):
            let change = AppliedChange.updatedExpenseAmount(id: expense.id, from: expense.amount, to: item.amount)
            expense.amount = item.amount
            return change
        case (.update, .subscription(let subscription)):
            let change = AppliedChange.updatedSubscriptionAmount(id: subscription.id, from: subscription.amount, to: item.amount)
            subscription.amount = item.amount
            return change
        case (.delete, .expense(let expense)):
            let snapshot = ExpenseSnapshot(
                amount: expense.amount,
                currency: expense.currency,
                date: expense.date,
                note: expense.note,
                categoryName: expense.category?.name,
                source: expense.source
            )
            context.delete(expense)
            return .deletedExpense(snapshot)
        case (.delete, .subscription(let subscription)):
            // Ending, not erasing: posting stops but the posted history stays.
            let change = AppliedChange.endedSubscription(id: subscription.id, previousEndDate: subscription.endDate)
            subscription.isActive = false
            subscription.endDate = .now
            return change
        case (.update, nil), (.delete, nil):
            preconditionFailure("resolveTargets guarantees a target for update/delete")
        }
    }

    private static func singleTitle(_ item: ParsedItem) -> String {
        let money = Money.format(item.amount, currency: item.currency)
        switch (item.action, item.kind) {
        case (.create, .expense):
            return "Logged \(money) · \(item.categoryName ?? item.note)"
        case (.create, .subscription):
            return "Added \(item.note) · \(money) \(item.cadence ?? "monthly")"
        case (.update, _):
            return "Updated \(item.note) · \(money)"
        case (.delete, .expense):
            return item.amount > 0 ? "Deleted \(item.note) · \(money)" : "Deleted \(item.note)"
        case (.delete, .subscription):
            return "Ended \(item.note)"
        }
    }

    private func createExpense(_ item: ParsedItem) -> AppliedChange {
        let expense = Expense(
            amount: item.amount,
            currency: item.currency,
            date: item.date,
            note: item.note,
            source: "voice",
            category: category(named: item.categoryName)
        )
        context.insert(expense)
        return .createdExpense(id: expense.id)
    }

    private func createSubscription(_ item: ParsedItem) -> AppliedChange {
        let calendar = Calendar.current
        let subscription = Subscription(
            name: item.note,
            amount: item.amount,
            currency: item.currency,
            cadence: item.cadence ?? "monthly",
            billingDay: calendar.component(.day, from: item.date),
            category: category(named: item.categoryName)
        )
        subscription.startDate = item.date
        if subscription.cadence == "yearly" {
            subscription.billingMonth = calendar.component(.month, from: item.date)
        }
        context.insert(subscription)
        return .createdSubscription(id: subscription.id)
    }

    // Newest first so "el café" means the latest café; an exact amount, when
    // spoken, disambiguates between same-named records.
    private func latestExpense(matching name: String, amountHint: Decimal) -> Expense? {
        let descriptor = FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let matches = ((try? context.fetch(descriptor)) ?? []).filter { Self.nameMatches(name, $0.note) }
        if amountHint > 0, let exact = matches.first(where: { $0.amount == amountHint }) { return exact }
        return matches.first
    }

    private func activeSubscription(matching name: String) -> Subscription? {
        let descriptor = FetchDescriptor<Subscription>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? [])
            .first { $0.isActive && Self.nameMatches(name, $0.name) }
    }

    func expense(id: UUID) -> Expense? {
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func subscription(id: UUID) -> Subscription? {
        let descriptor = FetchDescriptor<Subscription>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func category(named name: String?) -> Category? {
        guard let name else { return nil }
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.name == name })
        return try? context.fetch(descriptor).first
    }
}
