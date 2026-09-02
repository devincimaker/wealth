import Foundation

// Config flows Secrets.local.xcconfig → build settings → Info.plist → here.
// A missing value is surfaced loudly at the point of use (§8), never papered
// over. The app holds no model API keys: the voice path talks to the Wealth
// server (server/), which owns the Whisper key and the Claude subscription auth.
enum Secrets {
    static let serverURL = "WEALTH_SERVER_URL"
    static let serverToken = "WEALTH_SERVER_TOKEN"

    static func value(_ name: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: name) as? String,
              !raw.isEmpty else { return nil }
        return raw
    }
}
