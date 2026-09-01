import Foundation
import SwiftData

// Auto-posts subscription expenses on app open, catching up anything missed
// since the last launch. No server: the walk from lastPostedDate is the queue.
enum SubscriptionPoster {
    @MainActor
    static func postDue(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let subscriptions = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        var posted = false
        for subscription in subscriptions {
            for due in dueDates(for: subscription, until: now, calendar: calendar) {
                let expense = Expense(
                    amount: subscription.amount,
                    currency: subscription.currency,
                    date: due,
                    note: subscription.name,
                    source: "subscription",
                    category: subscription.category
                )
                expense.subscription = subscription
                context.insert(expense)
                subscription.lastPostedDate = due
                posted = true
            }
        }
        if posted { try? context.save() }
    }

    // Billing dates that are due (start..now, past lastPostedDate, before any
    // endDate). Ordered oldest first so lastPostedDate advances monotonically.
    static func dueDates(for subscription: Subscription, until now: Date, calendar: Calendar = .current) -> [Date] {
        guard subscription.isActive else { return [] }
        var dates: [Date] = []
        forEachOccurrence(of: subscription, calendar: calendar) { due in
            if due > now { return false }
            if isPostable(due, for: subscription, calendar: calendar) { dates.append(due) }
            return true
        }
        return dates
    }

    // Feeds "next: Netflix posts Sep 12" on the subscriptions screen.
    static func nextDueDate(for subscription: Subscription, after date: Date, calendar: Calendar = .current) -> Date? {
        guard subscription.isActive else { return nil }
        var next: Date?
        forEachOccurrence(of: subscription, calendar: calendar) { due in
            if let end = subscription.endDate, due > end { return false }
            if due > date, due >= calendar.startOfDay(for: subscription.startDate) {
                next = due
                return false
            }
            return true
        }
        return next
    }

    // Walks billing occurrences from the start month; the visitor returns
    // false to stop. Occurrences arrive in ascending order.
    private static func forEachOccurrence(
        of subscription: Subscription,
        calendar: Calendar,
        visit: (Date) -> Bool
    ) {
        var components = calendar.dateComponents([.year, .month], from: subscription.startDate)
        let monthStep = subscription.cadence == "yearly" ? 12 : 1
        if subscription.cadence == "yearly", let billingMonth = subscription.billingMonth {
            components.month = billingMonth
        }
        while true {
            guard let monthStart = calendar.date(from: components),
                  let due = billingDate(for: subscription, inMonthOf: monthStart, calendar: calendar)
            else { return }
            if !visit(due) { return }
            components.month = (components.month ?? 1) + monthStep
        }
    }

    private static func billingDate(for subscription: Subscription, inMonthOf monthStart: Date, calendar: Calendar) -> Date? {
        // Clamp day 31 into shorter months (Feb posts on the 28th).
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
        let day = min(max(subscription.billingDay, 1), dayRange.count)
        return calendar.date(byAdding: .day, value: day - 1, to: monthStart)
    }

    private static func isPostable(_ due: Date, for subscription: Subscription, calendar: Calendar) -> Bool {
        guard due >= calendar.startOfDay(for: subscription.startDate) else { return false }
        if let end = subscription.endDate, due > end { return false }
        if let last = subscription.lastPostedDate, due <= last { return false }
        return true
    }
}
