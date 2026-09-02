import Foundation

// The voice pipeline's single round trip: the capture's audio (or a retry's
// saved transcript) plus the ledger context go to the Wealth server, which
// transcribes with Whisper and parses with Claude on subscription auth
// (server/ in this repo); validated items come back. The context rides along
// because the ledger lives on this device: the model resolves references
// against real records it is shown, never against records it can't see.
struct ParseContext: Encodable, Equatable {
    struct SubscriptionRef: Encodable, Equatable {
        let name: String
        let amount: Decimal
        let currency: String
        let cadence: String
    }

    struct ExpenseRef: Encodable, Equatable {
        let note: String
        let amount: Decimal
        let currency: String
        let date: String
    }

    let today: String
    let defaultCurrency: String
    let categories: [String]
    let subscriptions: [SubscriptionRef]
    // Newest first; the server tells the model "el último gasto" is the first.
    let recentExpenses: [ExpenseRef]
}

struct AssistantReply: Equatable {
    let transcript: String
    // Empty when the transcript held nothing usable; the transcript is still
    // worth keeping so Retry never re-records.
    let items: [ParsedItem]
}

protocol AssistantService: Sendable {
    func parse(audioURL: URL?, transcript: String?, context: ParseContext) async throws -> AssistantReply
}

enum VoiceError: LocalizedError, Equatable {
    case missingKey(String)
    case requestFailed(service: String, status: Int)
    case nothingHeard
    case noAmount
    case targetNotFound(String)

    // These read as the activity-log row title, so each failure says which
    // kind it was: a silent recording reads differently from a dead server.
    var errorDescription: String? {
        switch self {
        case .missingKey(let name):
            "Add \(name) to Secrets.local.xcconfig"
        case .requestFailed(let service, let status):
            "\(service) answered \(status)"
        case .nothingHeard:
            "Didn't catch that"
        case .noAmount:
            "Didn't catch an amount"
        case .targetNotFound(let name):
            "Couldn't find \"\(name)\" in your records"
        }
    }
}

struct ServerAssistantService: AssistantService {
    // Optional so missing config surfaces as a failed row naming the fix.
    let baseURL: URL?
    let token: String?

    func parse(audioURL: URL?, transcript: String?, context: ParseContext) async throws -> AssistantReply {
        guard let baseURL else { throw VoiceError.missingKey(Secrets.serverURL) }
        guard let token else { throw VoiceError.missingKey(Secrets.serverToken) }
        var request = URLRequest(url: baseURL.appending(path: "v1/parse"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let boundary = "wealth-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.multipartBody(
            boundary: boundary,
            context: context,
            transcript: transcript,
            audioData: audioURL.map { try Data(contentsOf: $0) }
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try Self.reply(fromResponse: data, status: status, categoryNames: context.categories, now: .now)
    }

    static func multipartBody(boundary: String, context: ParseContext, transcript: String?, audioData: Data?) throws -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        func field(_ name: String, _ value: Data) {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append(value)
            append("\r\n")
        }
        field("context", try JSONEncoder().encode(context))
        if let transcript { field("transcript", Data(transcript.utf8)) }
        if let audioData {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"audio\"; filename=\"capture.m4a\"\r\n")
            append("Content-Type: audio/m4a\r\n\r\n")
            body.append(audioData)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        return body
    }

    // The server already validated and normalized; this maps to app types and
    // re-checks the parts that depend on device state (category list, clock).
    static func reply(fromResponse data: Data, status: Int, categoryNames: [String], now: Date) throws -> AssistantReply {
        struct ServerItem: Decodable {
            let kind: String?
            let action: String?
            let amount: Decimal?
            let currency: String?
            let note: String?
            let category: String?
            let date: String?
            let cadence: String?
        }
        struct ServerReply: Decodable {
            let transcript: String?
            let items: [ServerItem]?
            let code: String?
        }
        let reply = try? JSONDecoder().decode(ServerReply.self, from: data)
        switch status {
        case 200:
            break
        case 422 where reply?.code == "no_amount":
            // The transcript survives so Retry re-parses instead of re-recording.
            return AssistantReply(transcript: reply?.transcript ?? "", items: [])
        case 422:
            throw VoiceError.nothingHeard
        default:
            throw VoiceError.requestFailed(service: "Wealth server", status: status)
        }
        let items = (reply?.items ?? []).map { item in
            ParsedItem(
                kind: ParsedItem.Kind(rawValue: item.kind ?? "") ?? .expense,
                action: ParsedItem.Action(rawValue: item.action ?? "") ?? .create,
                amount: item.amount ?? 0,
                currency: item.currency ?? "ARS",
                note: item.note ?? "",
                categoryName: matchCategory(item.category, in: categoryNames),
                date: resolveDate(item.date, now: now),
                cadence: item.cadence
            )
        }
        return AssistantReply(transcript: reply?.transcript ?? "", items: items)
    }

    static func matchCategory(_ name: String?, in categoryNames: [String]) -> String? {
        guard let name else { return nil }
        return categoryNames.first { $0.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    static func resolveDate(_ string: String?, now: Date) -> Date {
        guard let string, let date = ISO8601DateFormatter.dateOnly.date(from: string) else { return now }
        // Same-day dictation keeps the real capture time instead of midnight.
        if Calendar.current.isDate(date, inSameDayAs: now) { return now }
        return date
    }
}

extension ISO8601DateFormatter {
    // A fresh instance per call: ISO8601DateFormatter isn't Sendable, and the
    // parse path is off the main actor. The local time zone matters: a bare
    // "2026-09-01" means that day where I am, not UTC midnight, which would
    // land the expense on the previous day west of Greenwich.
    static var dateOnly: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = .current
        return formatter
    }
}

#if DEBUG
// TODO(voice): DEBUG stand-in used when the server isn't configured. Two
// items so the multi-item path is what the simulator exercises.
struct MockAssistantService: AssistantService {
    func parse(audioURL: URL?, transcript: String?, context: ParseContext) async throws -> AssistantReply {
        try await Task.sleep(for: .seconds(1))
        return AssistantReply(
            transcript: transcript ?? "cuarenta mil pesos, cena con amigos",
            items: [
                ParsedItem(
                    kind: .expense,
                    action: .create,
                    amount: 40_000,
                    currency: "ARS",
                    note: "Cena con amigos",
                    categoryName: context.categories.first,
                    date: .now,
                    cadence: nil
                ),
                ParsedItem(
                    kind: .subscription,
                    action: .create,
                    amount: 200,
                    currency: "USD",
                    note: "Claude Pro",
                    categoryName: nil,
                    date: .now,
                    cadence: "monthly"
                ),
            ]
        )
    }
}
#endif

// The real client whenever the server is configured. Without it, DEBUG builds
// run on the mock and release builds fail each capture naming the missing key.
enum VoiceServices {
    static func assistant() -> any AssistantService {
        let url = Secrets.value(Secrets.serverURL).flatMap { URL(string: $0) }
        let token = Secrets.value(Secrets.serverToken)
        #if DEBUG
        if url == nil || token == nil { return MockAssistantService() }
        #endif
        return ServerAssistantService(baseURL: url, token: token)
    }
}
