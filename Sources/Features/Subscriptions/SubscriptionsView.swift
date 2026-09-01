import SwiftData
import SwiftUI

// The recurring list plus the monthly burn card (yearly amounts ÷ 12).
struct SubscriptionsView: View {
    @Environment(RateStore.self) private var rates
    @AppStorage("baseCurrency") private var baseCurrency = Money.defaultBaseCurrency
    @Query(sort: \Subscription.name) private var subscriptions: [Subscription]
    @State private var editing: Subscription?
    @State private var addingNew = false

    var body: some View {
        ZStack {
            Color.wBackground.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text("Subscriptions")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.wText)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 18)

                    burnCard

                    ForEach(subscriptions) { subscription in
                        Button { editing = subscription } label: {
                            SubscriptionRow(subscription: subscription, base: baseCurrency, rates: rates.rates)
                        }
                        .buttonStyle(.plain)
                    }

                    AddRowButton(title: "New subscription") { addingNew = true }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)

                    Color.clear.frame(height: 180)
                }
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $addingNew) { SubscriptionEditView(subscription: nil) }
        .sheet(item: $editing) { SubscriptionEditView(subscription: $0) }
    }

    private var burnCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Monthly burn")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Money.formatRounded(monthlyBurn, currency: baseCurrency))
                    .font(.wAmount(36))
                    .foregroundStyle(Color.wText)
                Text("/ month")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.wTextSecondary)
            }
            Text(summaryLine)
                .font(.system(size: 12))
                .foregroundStyle(Color.wTextTertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.wCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.wHairline, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var active: [Subscription] {
        subscriptions.filter(\.isActive)
    }

    private var monthlyBurn: Decimal {
        active.reduce(Decimal.zero) { total, subscription in
            let converted = Money.convert(
                subscription.amount,
                from: subscription.currency,
                to: baseCurrency,
                rates: rates.rates
            ) ?? 0
            return total + (subscription.cadence == "yearly" ? converted / 12 : converted)
        }
    }

    private var summaryLine: String {
        let count = active.count
        let plural = count == 1 ? "1 active" : "\(count) active"
        guard let next = active
            .compactMap({ subscription -> (Subscription, Date)? in
                guard let date = SubscriptionPoster.nextDueDate(for: subscription, after: .now) else { return nil }
                return (subscription, date)
            })
            .min(by: { $0.1 < $1.1 })
        else { return plural }
        let day = next.1.formatted(.dateTime.month(.abbreviated).day())
        return "\(plural) · next: \(next.0.name) posts \(day)"
    }
}

private struct SubscriptionRow: View {
    let subscription: Subscription
    let base: String
    let rates: [String: Decimal]

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.wCardRaised)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(initial)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.wTextSecondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(subscription.isActive ? Color.wText : Color.wTextTertiary)
                Text(scheduleText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.wTextTertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(.wAmount(15))
                    .foregroundStyle(Color.wText)
                if let monthlyText {
                    Text(monthlyText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.wTextTertiary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .contentShape(.rect)
        .opacity(subscription.isActive ? 1 : 0.55)
    }

    private var initial: String {
        String(subscription.name.prefix(1)).uppercased()
    }

    private var amountText: String {
        let base = Money.format(subscription.amount, currency: subscription.currency)
        return subscription.cadence == "yearly" ? "\(base) / yr" : base
    }

    private var scheduleText: String {
        guard subscription.isActive else { return "Paused" }
        if subscription.cadence == "yearly" {
            guard let next = SubscriptionPoster.nextDueDate(for: subscription, after: .now) else { return "Yearly" }
            return "Yearly · posts \(next.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return "Monthly · posts on the \(ordinal(subscription.billingDay))"
    }

    // Yearly rows show their monthly share; foreign currencies show the
    // converted monthly equivalent.
    private var monthlyText: String? {
        let converted = Money.convert(subscription.amount, from: subscription.currency, to: base, rates: rates)
        guard subscription.cadence == "yearly" || subscription.currency != base, let converted else { return nil }
        let monthly = subscription.cadence == "yearly" ? converted / 12 : converted
        return "≈ \(Money.formatRounded(monthly, currency: base)) / mo"
    }

    private func ordinal(_ day: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: day)) ?? "\(day)"
    }
}
