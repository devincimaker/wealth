#if DEBUG
import Foundation
import SwiftData

// Populates a simulator run with the canvas's example ledger, so screens can
// be checked against the design without hand-entering data.
// Enabled by launching with -seedSampleData.
enum SampleData {
    private struct ExpenseSeed {
        let amount: Decimal
        let currency: String
        let daysAgo: Int
        let note: String
        let category: String
    }

    private struct SubscriptionSeed {
        let name: String
        let amount: Decimal
        let currency: String
        let billingDay: Int
        let category: String
    }

    private struct CaptureSeed {
        let status: CaptureStatus
        let title: String
        let transcript: String
    }

    @MainActor
    static func seedIfRequested(in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedSampleData") else { return }
        guard (try? context.fetchCount(FetchDescriptor<Expense>())) == 0 else { return }
        let categories = (try? context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        func category(_ name: String) -> Category? { categories.first { $0.name == name } }

        for seed in expenseSeeds {
            context.insert(Expense(
                amount: seed.amount,
                currency: seed.currency,
                date: day(seed.daysAgo),
                note: seed.note,
                category: category(seed.category)
            ))
        }

        for seed in subscriptionSeeds {
            let subscription = Subscription(
                name: seed.name,
                amount: seed.amount,
                currency: seed.currency,
                billingDay: seed.billingDay,
                category: category(seed.category)
            )
            subscription.startDate = day(90)
            subscription.lastPostedDate = day(0)
            context.insert(subscription)
        }

        for seed in captureSeeds {
            let capture = VoiceCapture(audioFileName: "\(UUID().uuidString).m4a")
            capture.captureStatus = seed.status
            capture.title = seed.title
            capture.transcript = seed.transcript
            context.insert(capture)
        }
        try? context.save()
    }

    // Clamped into the current month so the home list has something to show
    // no matter which day of the month the sample is seeded on.
    private static func day(_ offset: Int) -> Date {
        let calendar = Calendar.current
        let dayOfMonth = calendar.component(.day, from: .now)
        return calendar.date(byAdding: .day, value: -min(offset, dayOfMonth - 1), to: .now) ?? .now
    }

    private static let expenseSeeds = [
        ExpenseSeed(amount: 40000, currency: "ARS", daysAgo: 0, note: "Cena en La Carnicería", category: "Food & Drink"),
        ExpenseSeed(amount: 18500, currency: "ARS", daysAgo: 1, note: "Verdulería Doña Rosa", category: "Groceries"),
        ExpenseSeed(amount: 7200, currency: "ARS", daysAgo: 1, note: "Uber a Palermo", category: "Transport"),
        ExpenseSeed(amount: 24900, currency: "ARS", daysAgo: 1, note: "Farmacity", category: "Health"),
        ExpenseSeed(amount: 22000, currency: "ARS", daysAgo: 3, note: "Cine con Flor", category: "Entertainment"),
        ExpenseSeed(amount: 9800, currency: "ARS", daysAgo: 3, note: "Café Registrado", category: "Food & Drink"),
        ExpenseSeed(amount: 420_000, currency: "ARS", daysAgo: 5, note: "Alquiler", category: "Housing"),
        ExpenseSeed(amount: 62, currency: "USD", daysAgo: 6, note: "Mercado Libre", category: "Other"),
    ]

    private static let subscriptionSeeds = [
        SubscriptionSeed(name: "Claude Pro", amount: 20, currency: "USD", billingDay: 1, category: "Subscriptions"),
        SubscriptionSeed(name: "Netflix", amount: 15999, currency: "ARS", billingDay: 12, category: "Entertainment"),
        SubscriptionSeed(name: "Spotify", amount: 6999, currency: "ARS", billingDay: 18, category: "Entertainment"),
        SubscriptionSeed(name: "Megatlon", amount: 42000, currency: "ARS", billingDay: 1, category: "Health"),
    ]

    // One capture per status, so the pill and activity log can be checked.
    private static let captureSeeds = [
        CaptureSeed(
            status: .applied,
            title: "Logged AR$ 40.000 · Food & Drink",
            transcript: "cuarenta mil pesos, cena con amigos en La Carnicería"
        ),
        CaptureSeed(
            status: .failed,
            title: "Didn't catch an amount",
            transcript: "eh… anotá lo del súper de hoy"
        ),
        CaptureSeed(
            status: .rewound,
            title: "Logged AR$ 9.800 · Café Registrado",
            transcript: "nueve mil ochocientos, café con Juan"
        ),
    ]
}
#endif
