import Foundation

// API keys flow Secrets.local.xcconfig → build settings → Info.plist → here.
// A missing key is surfaced loudly at the point of use (§8), never papered over.
// One key covers the whole voice path: OpenAI transcribes and parses.
enum Secrets {
    static let openAIKey = "OPENAI_API_KEY"

    static func value(_ name: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: name) as? String,
              !raw.isEmpty else { return nil }
        return raw
    }
}
