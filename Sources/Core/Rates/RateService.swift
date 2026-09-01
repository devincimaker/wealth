import Foundation

// Live exchange rates, fetched automatically: never entered by hand.
// ARS uses the DolarAPI blue rate (the rate my money actually moves at);
// any other non-USD currency falls back to Frankfurter. Both quote units
// per 1 USD, which is the convention Money.convert expects.
protocol RateService: Sendable {
    func fetchRates(for currencies: [String]) async throws -> [String: Decimal]
}

struct APIRateService: RateService {
    func fetchRates(for currencies: [String]) async throws -> [String: Decimal] {
        var rates: [String: Decimal] = [:]
        var lastError: Error?
        if currencies.contains("ARS") {
            do { rates["ARS"] = try await fetchBlueRate() } catch { lastError = error }
        }
        let others = currencies.filter { $0 != "ARS" && $0 != "USD" }
        if !others.isEmpty {
            do { rates.merge(try await fetchFrankfurterRates(others)) { _, new in new } } catch { lastError = error }
        }
        // Partial results still update the cache; only a total miss throws.
        if rates.isEmpty, let lastError { throw lastError }
        return rates
    }

    private func fetchBlueRate() async throws -> Decimal {
        let url = URL(string: "https://dolarapi.com/v1/dolares/blue")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try Self.blueRate(fromJSON: data)
    }

    private func fetchFrankfurterRates(_ currencies: [String]) async throws -> [String: Decimal] {
        let list = currencies.joined(separator: ",")
        let url = URL(string: "https://api.frankfurter.app/latest?from=USD&to=\(list)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try Self.frankfurterRates(fromJSON: data)
    }

    // Selling rate: what a dollar costs in pesos, i.e. what my pesos are worth.
    static func blueRate(fromJSON data: Data) throws -> Decimal {
        struct Blue: Decodable { let venta: Decimal }
        return try JSONDecoder().decode(Blue.self, from: data).venta
    }

    static func frankfurterRates(fromJSON data: Data) throws -> [String: Decimal] {
        struct Latest: Decodable { let rates: [String: Decimal] }
        return try JSONDecoder().decode(Latest.self, from: data).rates
    }
}
