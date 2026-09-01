import Foundation

// Transcript → structured expense via a small OpenAI model, using structured
// outputs so the schema is enforced at decode time rather than trusted.
// Categories only ever match the existing list; the model never invents one.
struct ParsedExpense: Equatable {
    let amount: Decimal
    let currency: String
    let note: String
    let categoryName: String?
    let date: Date
}

protocol ParsingService: Sendable {
    func parse(transcript: String, categoryNames: [String], defaultCurrency: String, now: Date) async throws -> ParsedExpense
}

// Chat Completions wraps the JSON answer in a string, so this decodes twice:
// the envelope, then the schema-shaped payload inside `content`.
private struct CompletionResponse: Decodable {
    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
        // Set instead of `content` when the model declines to answer.
        let refusal: String?
    }

    let choices: [Choice]
}

private struct ExpensePayload: Decodable {
    let amount: Decimal?
    let currency: String?
    let note: String?
    let category: String?
    let date: String?
}

struct OpenAIParsingService: ParsingService {
    // Same key as transcription: one vendor, one credential for the whole
    // voice path. Optional so a missing key surfaces as a failed row.
    let apiKey: String?

    func parse(transcript: String, categoryNames: [String], defaultCurrency: String, now: Date) async throws -> ParsedExpense {
        guard let apiKey else { throw VoiceError.missingKey(Secrets.openAIKey) }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: Self.requestBody(
                transcript: transcript,
                categoryNames: categoryNames,
                defaultCurrency: defaultCurrency,
                now: now
            )
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw VoiceError.requestFailed(service: "OpenAI", status: status) }
        return try Self.parsedExpense(fromResponse: data, categoryNames: categoryNames, now: now)
    }

    static func requestBody(transcript: String, categoryNames: [String], defaultCurrency: String, now: Date) -> [String: Any] {
        let today = ISO8601DateFormatter.dateOnly.string(from: now)
        let system = """
        Extract exactly one expense from a dictated note (Spanish, English, or mixed). \
        Today is \(today). Resolve relative dates ("ayer", "last Friday") against it. \
        Currency: ISO 4217; "pesos" means ARS, "dólares"/"dollars" means USD; \
        when unstated use \(defaultCurrency). \
        Category must be one of: \(categoryNames.joined(separator: ", ")). \
        Use null when none clearly fits; never invent a category. \
        The note is a short merchant or description, cleaned up, in the speaker's language. \
        Set amount to 0 when the note states no amount.
        """
        // strict mode requires every property listed in `required` and no
        // extras, so "optional" is expressed as a nullable type instead.
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "amount": ["type": "number"],
                "currency": ["type": "string"],
                "note": ["type": "string"],
                "category": ["type": ["string", "null"]],
                "date": ["type": "string", "description": "YYYY-MM-DD"],
            ],
            "required": ["amount", "currency", "note", "category", "date"],
            "additionalProperties": false,
        ]
        return [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": transcript],
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": ["name": "expense", "strict": true, "schema": schema],
            ],
        ]
    }

    static func parsedExpense(fromResponse data: Data, categoryNames: [String], now: Date) throws -> ParsedExpense {
        let response = try JSONDecoder().decode(CompletionResponse.self, from: data)
        if response.choices.first?.message.refusal != nil { throw VoiceError.refused }
        guard let content = response.choices.first?.message.content,
              let payload = try? JSONDecoder().decode(ExpensePayload.self, from: Data(content.utf8)),
              let amount = payload.amount, amount > 0 else { throw VoiceError.noAmount }
        return ParsedExpense(
            amount: amount,
            currency: payload.currency?.uppercased() ?? "ARS",
            note: payload.note ?? "",
            categoryName: matchCategory(payload.category, in: categoryNames),
            date: resolveDate(payload.date, now: now)
        )
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
// TODO(voice): DEBUG stand-in used when no key is configured.
struct MockParsingService: ParsingService {
    func parse(transcript: String, categoryNames: [String], defaultCurrency: String, now: Date) async throws -> ParsedExpense {
        try await Task.sleep(for: .seconds(1))
        return ParsedExpense(
            amount: 40_000,
            currency: "ARS",
            note: "Cena con amigos",
            categoryName: categoryNames.first,
            date: now
        )
    }
}
#endif

// Real services whenever the key exists. Without it, DEBUG builds run on
// mocks and release builds fail each capture with the missing key named.
enum VoiceServices {
    static func transcription() -> any TranscriptionService {
        let key = Secrets.value(Secrets.openAIKey)
        #if DEBUG
        if key == nil { return MockTranscriptionService() }
        #endif
        return WhisperTranscriptionService(apiKey: key)
    }

    static func parsing() -> any ParsingService {
        let key = Secrets.value(Secrets.openAIKey)
        #if DEBUG
        if key == nil { return MockParsingService() }
        #endif
        return OpenAIParsingService(apiKey: key)
    }
}
