import Foundation

// Formatting and conversion for amounts. es-AR conventions throughout:
// "." groups thousands, "," separates decimals, and whole amounts drop them.
enum Money {
    static let defaultBaseCurrency = "USD"

    static func format(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = isWhole(amount) ? 0 : 2
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0"
        return "\(symbol(for: currency)) \(number)"
    }

    // Totals and row approximations show whole units; exact cents stay on the expense.
    static func formatRounded(_ amount: Decimal, currency: String) -> String {
        format(rounded(amount), currency: currency)
    }

    // `rates` are units of currency per 1 USD (DolarAPI/Frankfurter convention).
    // nil when a needed rate is unknown; callers surface that, never guess.
    static func convert(_ amount: Decimal, from source: String, to target: String, rates: [String: Decimal]) -> Decimal? {
        if source == target { return amount }
        guard let sourceRate = perDollarRate(for: source, in: rates),
              let targetRate = perDollarRate(for: target, in: rates) else { return nil }
        return amount / sourceRate * targetRate
    }

    static func symbol(for code: String) -> String {
        switch code {
        case "USD": "US$"
        case "ARS": "AR$"
        default: code
        }
    }

    private static func perDollarRate(for code: String, in rates: [String: Decimal]) -> Decimal? {
        if code == "USD" { return 1 }
        guard let rate = rates[code], rate > 0 else { return nil }
        return rate
    }

    private static func rounded(_ amount: Decimal) -> Decimal {
        var value = amount
        var result = Decimal()
        NSDecimalRound(&result, &value, 0, .plain)
        return result
    }

    private static func isWhole(_ amount: Decimal) -> Bool {
        rounded(amount) == amount
    }
}
