import Foundation

// Formatting and conversion for amounts. es-AR conventions throughout:
// "." groups thousands, "," separates decimals, and whole amounts drop them.
enum Money {
    static let baseCurrency = "USD"

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

    // nil when no rate is known for `currency`; callers surface that, never guess.
    static func convertToBase(_ amount: Decimal, currency: String, rates: [String: Decimal]) -> Decimal? {
        if currency == baseCurrency { return amount }
        guard let rate = rates[currency], rate > 0 else { return nil }
        return amount / rate
    }

    private static func symbol(for code: String) -> String {
        switch code {
        case "USD": "US$"
        case "ARS": "AR$"
        default: code
        }
    }

    private static func isWhole(_ amount: Decimal) -> Bool {
        var value = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return rounded == amount
    }
}
