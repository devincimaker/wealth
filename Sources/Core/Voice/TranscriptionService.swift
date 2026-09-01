import Foundation

// Audio → text. Whisper because it handles half-Spanish dictation well;
// deliberately no Apple speech recognition (poor Spanish). The protocol is the
// seam that lets this move server-side later without touching the UI.
protocol TranscriptionService: Sendable {
    func transcribe(audioAt url: URL) async throws -> String
}

enum VoiceError: LocalizedError, Equatable {
    case missingKey(String)
    case requestFailed(service: String, status: Int)
    case noAmount
    case refused

    // These read as the activity-log row title, so each failure says which
    // kind it was: a bad recording reads differently from a dead network.
    var errorDescription: String? {
        switch self {
        case .missingKey(let name):
            "Add \(name) to Secrets.local.xcconfig"
        case .requestFailed(let service, let status):
            "\(service) answered \(status)"
        case .noAmount:
            "Didn't catch an amount"
        case .refused:
            "The model wouldn't answer that one"
        }
    }
}

struct WhisperTranscriptionService: TranscriptionService {
    // Optional so a missing key surfaces as a failed row naming the fix,
    // rather than as a service that silently does nothing.
    let apiKey: String?

    func transcribe(audioAt url: URL) async throws -> String {
        guard let apiKey else { throw VoiceError.missingKey(Secrets.openAIKey) }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let boundary = "wealth-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.multipartBody(boundary: boundary, audioData: Data(contentsOf: url))
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw VoiceError.requestFailed(service: "Whisper", status: status) }
        struct Transcription: Decodable { let text: String }
        return try JSONDecoder().decode(Transcription.self, from: data).text
    }

    // No `language` pin: dictation mixes Spanish and English and Whisper detects both.
    static func multipartBody(boundary: String, audioData: Data) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\nwhisper-1\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"capture.m4a\"\r\n")
        append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}

#if DEBUG
// TODO(voice): DEBUG stand-in until real keys land in Secrets.local.xcconfig.
struct MockTranscriptionService: TranscriptionService {
    func transcribe(audioAt url: URL) async throws -> String {
        try await Task.sleep(for: .seconds(1))
        return "cuarenta mil pesos, cena con amigos en La Carnicería"
    }
}
#endif
