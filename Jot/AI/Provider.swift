import Foundation

enum Provider: String, CaseIterable, Identifiable, Codable, Sendable {
    case apple, anthropic, openai, gemini, ollama

    var id: String { rawValue }

    var name: String {
        switch self {
        case .apple: "Apple On-Device"
        case .anthropic: "Anthropic"
        case .openai: "OpenAI"
        case .gemini: "Google Gemini"
        case .ollama: "Ollama"
        }
    }

    var symbol: String {
        switch self {
        case .apple: "apple.logo"
        case .anthropic: "sparkle"
        case .openai: "circle.hexagongrid"
        case .gemini: "diamond"
        case .ollama: "desktopcomputer"
        }
    }

    var needsKey: Bool { self == .anthropic || self == .openai || self == .gemini }

    /// Preselected model before the user fetches the live list.
    var defaultModel: String {
        switch self {
        case .apple: "on-device"
        case .anthropic: "claude-opus-5-5"
        case .openai, .gemini, .ollama: ""
        }
    }

    var keyPage: URL? {
        switch self {
        case .anthropic: URL(string: "https://platform.claude.com/settings/keys")
        case .openai: URL(string: "https://platform.openai.com/api-keys")
        case .gemini: URL(string: "https://aistudio.google.com/apikey")
        case .apple, .ollama: nil
        }
    }
}

struct Expansion: Codable, Sendable {
    var title: String
    var items: [String]
}

/// Everything one AI call needs, captured on the main actor.
struct AIRequest: Sendable {
    let provider: Provider
    let model: String
    let key: String?
    let ollamaURL: String
}

enum AIError: LocalizedError {
    case http(Int, String)
    case refused
    case empty
    case unavailable(String)
    case noModel

    var errorDescription: String? {
        switch self {
        case .http(let code, let message): "HTTP \(code): \(message)"
        case .refused: "The model declined this note."
        case .empty: "The model returned no checklist."
        case .unavailable(let reason): reason
        case .noModel: "Pick a model in Settings → Models."
        }
    }
}

enum AI {
    static let instructions = """
    You turn a quick, rough note into an actionable plan.
    Return a short title (at most 8 words) and 3 to 8 checklist items.
    Each item is one concrete action that starts with a verb and is specific to the note: \
    name the tools, versions and comparisons involved. No fluff, no numbering.
    """

    static func schema() -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "items": ["type": "array", "items": ["type": "string"]],
            ],
            "required": ["title", "items"],
            "additionalProperties": false,
        ]
    }

    static func expand(_ note: String, with r: AIRequest) async throws -> Expansion {
        let result: Expansion
        switch r.provider {
        case .apple:
            result = try await AppleModel.expand(note)
        case .anthropic:
            guard !r.model.isEmpty else { throw AIError.noModel }
            result = try await AnthropicClient(key: r.key ?? "").expand(note, model: r.model)
        case .openai, .gemini, .ollama:
            guard !r.model.isEmpty else { throw AIError.noModel }
            result = try await OpenAICompatClient(r).expand(note, model: r.model)
        }
        guard !result.items.isEmpty else { throw AIError.empty }
        return result
    }

    static func models(_ r: AIRequest) async throws -> [String] {
        switch r.provider {
        case .apple: ["on-device"]
        case .anthropic: try await AnthropicClient(key: r.key ?? "").models()
        case .openai, .gemini, .ollama: try await OpenAICompatClient(r).models()
        }
    }
}

enum HTTP {
    static func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw AIError.http(code, message(from: data)) }
        return try JSONDecoder().decode(type, from: data)
    }

    static func json(_ url: URL, body: [String: Any]? = nil, headers: [String: String]) throws -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        if let body {
            request.httpMethod = "POST"
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    /// Anthropic, OpenAI and Gemini all nest a `message` under `error`; Gemini sometimes wraps it in an array.
    private static func message(from data: Data) -> String {
        struct Wrapped: Decodable { struct E: Decodable { let message: String }; let error: E }
        if let w = try? JSONDecoder().decode(Wrapped.self, from: data) { return w.error.message }
        if let w = try? JSONDecoder().decode([Wrapped].self, from: data), let first = w.first { return first.error.message }
        return String(decoding: data.prefix(300), as: UTF8.self)
    }
}
