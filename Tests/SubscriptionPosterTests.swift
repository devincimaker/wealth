import Foundation
import Testing
@testable import Wealth

@MainActor
struct SubscriptionPosterTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func postsEveryMissedMonthSinceTheLastLaunch() {
        let subscription = makeSubscription(billingDay: 1, start: date(2026, 6, 1))
        subscription.lastPostedDate = date(2026, 6, 1)
        let due = SubscriptionPoster.dueDates(for: subscription, until: date(2026, 9, 15), calendar: calendar)
        #expect(due == [date(2026, 7, 1), date(2026, 8, 1), date(2026, 9, 1)])
    }

    @Test func postsNothingWhenAlreadyCaughtUp() {
        let subscription = makeSubscription(billingDay: 1, start: date(2026, 6, 1))
        subscription.lastPostedDate = date(2026, 9, 1)
        #expect(SubscriptionPoster.dueDates(for: subscription, until: date(2026, 9, 15), calendar: calendar).isEmpty)
    }

    @Test func firstRunPostsFromTheStartDate() {
        let subscription = makeSubscription(billingDay: 12, start: date(2026, 7, 12))
        let due = SubscriptionPoster.dueDates(for: subscription, until: date(2026, 9, 15), calendar: calendar)
        #expect(due == [date(2026, 7, 12), date(2026, 8, 12), date(2026, 9, 12)])
    }

    @Test func skipsBillingDatesBeforeTheStartDate() {
        let subscription = makeSubscription(billingDay: 1, start: date(2026, 6, 15))
        let due = SubscriptionPoster.dueDates(for: subscription, until: date(2026, 8, 5), calendar: calendar)
        #expect(due == [date(2026, 7, 1), date(2026, 8, 1)])
    }

    @Test func stopsAtTheEndDate() {
        let subscription = makeSubscription(billingDay: 1, start: date(2026, 6, 1))
        subscription.endDate = date(2026, 7, 20)
        let due = SubscriptionPoster.dueDates(for: subscription, until: date(2026, 9, 15), calendar: calendar)
        #expect(due == [date(2026, 6, 1), date(2026, 7, 1)])
    }

    @Test func clampsDayThirtyOneIntoShorterMonths() {
        let subscription = makeSubscription(billingDay: 31, start: date(2026, 1, 31))
        // February has no 31st, so that month posts on the 28th instead.
        let due = SubscriptionPoster.dueDates(for: subscription, until: date(2026, 3, 5), calendar: calendar)
        #expect(due == [date(2026, 1, 31), date(2026, 2, 28)])
    }

    @Test func inactiveSubscriptionsPostNothing() {
        let subscription = makeSubscription(billingDay: 1, start: date(2026, 6, 1))
        subscription.isActive = false
        #expect(SubscriptionPoster.dueDates(for: subscription, until: date(2026, 9, 15), calendar: calendar).isEmpty)
    }

    @Test func yearlySubscriptionsPostOnTheirBillingMonth() {
        let subscription = makeSubscription(billingDay: 14, start: date(2024, 3, 14))
        subscription.cadence = "yearly"
        subscription.billingMonth = 3
        let due = SubscriptionPoster.dueDates(for: subscription, until: date(2026, 9, 1), calendar: calendar)
        #expect(due == [date(2024, 3, 14), date(2025, 3, 14), date(2026, 3, 14)])
    }

    @Test func nextDueDateLooksForward() {
        let subscription = makeSubscription(billingDay: 12, start: date(2026, 1, 12))
        let next = SubscriptionPoster.nextDueDate(for: subscription, after: date(2026, 9, 1), calendar: calendar)
        #expect(next == date(2026, 9, 12))
    }

    @Test func nextDueDateIsNilAfterTheEndDate() {
        let subscription = makeSubscription(billingDay: 12, start: date(2026, 1, 12))
        subscription.endDate = date(2026, 8, 1)
        #expect(SubscriptionPoster.nextDueDate(for: subscription, after: date(2026, 9, 1), calendar: calendar) == nil)
    }

    @Test func nextDueDateIsNilWhenPaused() {
        let subscription = makeSubscription(billingDay: 12, start: date(2026, 1, 12))
        subscription.isActive = false
        #expect(SubscriptionPoster.nextDueDate(for: subscription, after: date(2026, 9, 1), calendar: calendar) == nil)
    }

    private func makeSubscription(billingDay: Int, start: Date) -> Subscription {
        let subscription = Subscription(name: "Netflix", amount: 15999, currency: "ARS", billingDay: billingDay)
        subscription.startDate = start
        return subscription
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
