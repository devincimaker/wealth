import Foundation
import Observation

// Cached current rates, refreshed on launch and foreground. The cache is the
// offline story: conversions always use the freshest rate we ever saw.
@MainActor
@Observable
final class RateStore {
    private(set) var rates: [String: Decimal] = [:]
    private(set) var lastUpdated: Date?

    private let service: any RateService
    private let defaults: UserDefaults
    private static let cacheKey = "rateCache"

    init(service: any RateService = APIRateService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.cacheKey),
           let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            rates = cache.rates
            lastUpdated = cache.lastUpdated
        }
    }

    func refresh(currencies: [String]) async {
        guard let fetched = try? await service.fetchRates(for: currencies), !fetched.isEmpty else { return }
        rates.merge(fetched) { _, new in new }
        lastUpdated = .now
        let cache = Cache(rates: rates, lastUpdated: lastUpdated ?? .now)
        if let data = try? JSONEncoder().encode(cache) {
            defaults.set(data, forKey: Self.cacheKey)
        }
    }

    // "Updated today, 09:12 · DolarAPI"
    var statusLine: String {
        guard let lastUpdated else { return "Waiting for the first update" }
        let time = lastUpdated.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(lastUpdated) {
            return "Updated today, \(time) · DolarAPI"
        }
        let day = lastUpdated.formatted(.dateTime.month(.abbreviated).day())
        return "Updated \(day), \(time) · DolarAPI"
    }

    private struct Cache: Codable {
        let rates: [String: Decimal]
        let lastUpdated: Date
    }
}
