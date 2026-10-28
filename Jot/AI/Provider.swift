import Foundation

enum Provider: String, CaseIterable, Identifiable, Codable, Sendable {
    case apple, claude, codex, gemini, ollama

    var id: String { rawValue }

    var name: String {
        switch self {
        case .apple: "Apple On-Device"
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .gemini: "Gemini CLI"
        case .ollama: "Ollama"
        }
    }

    var symbol: String {
        switch self {
        case .apple: "apple.logo"
        case .claude: "sparkle"
        case .codex: "circle.hexagongrid"
        case .gemini: "diamond"
        case .ollama: "desktopcomputer"
        }
    }

    /// Executable name for CLI providers.
    var tool: String? {
        switch self {
        case .claude: "claude"
        case .codex: "codex"
        case .gemini: "gemini"
        case .apple, .ollama: nil
        }
    }

    /// Model ids offered in the picker. Empty model = the CLI's own default.
    var suggestedModels: [String] {
        switch self {
        case .apple: ["on-device"]
        case .claude: ["opus", "sonnet", "haiku"]
        case .codex, .gemini, .ollama: []
        }
    }

    var installPage: URL? {
        switch self {
        case .claude: URL(string: "https://code.claude.com/docs/en/setup")
        case .codex: URL(string: "https://github.com/openai/codex")
        case .gemini: URL(string: "https://github.com/google-gemini/gemini-cli")
        case .apple, .ollama: nil
        }
    }

    /// Terminal command that signs the CLI in.
    var loginCommand: String? {
        switch self {
        case .claude: "claude auth login"
        case .codex: "codex login"
        case .gemini: "gemini"
        case .apple, .ollama: nil
        }
    }
}

struct Expansion: Codable, Sendable {
    var title: String
    var items: [String]
    /// Local "yyyy-MM-dd HH:mm", or empty when the note names no time.
    var remindAt: String
}

/// Everything one AI call needs, captured on the main actor.
struct AIRequest: Sendable {
    let provider: Provider
    let model: String
    let ollamaURL: String
}

enum AIError: LocalizedError {
    case http(Int, String)
    case refused
    case empty
    case unavailable(String)
    case noModel
    case cli(String, String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let message): "HTTP \(code): \(message)"
        case .refused: "The model declined this note."
        case .empty: "The model returned no checklist."
        case .unavailable(let reason): reason
        case .noModel: "Pick a model in Settings → Models."
        case .cli(let tool, let message): "\(tool): \(message)"
        }
    }
}

enum AI {
    static var instructions: String {
        let now = Date.now.formatted(.dateTime.weekday(.wide).year().month().day().hour().minute())
        return """
        You turn a quick, rough note into a short title (at most 8 words) and a checklist.
        If the note lists things, such as groceries to buy or things to pack, the items are exactly \
        those things, one per item (for example "Buy milk"), and nothing else.
        Otherwise give 3 to 8 concrete actions that start with a verb and are specific to the note, \
        using the tools, versions and comparisons it mentions. No fluff, no numbering.
        If the note asks to be reminded at a time, set remindAt to that local time as "yyyy-MM-dd HH:mm" \
        (a time already past today means tomorrow). Otherwise set remindAt to "".
        It is now \(now).
        """
    }

    /// Parses `Expansion.remindAt`; nil when empty, malformed or in the past.
    static func remindDate(_ text: String) -> Date? {
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd HH:mm"
        format.locale = Locale(identifier: "en_US_POSIX")
        guard let date = format.date(from: text), date > .now else { return nil }
        return date
    }

    static func schema() -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "items": ["type": "array", "items": ["type": "string"]],
                "remindAt": ["type": "string"],
            ],
            "required": ["title", "items", "remindAt"],
            "additionalProperties": false,
        ]
    }

    static func schemaJSON() throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: schema()), as: UTF8.self)
    }

    /// Parses a JSON reply, tolerating code fences or text around the object.
    static func decode(_ data: Data) throws -> Expansion {
        let text = String(decoding: data, as: UTF8.self)
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { throw AIError.empty }
        return try JSONDecoder().decode(Expansion.self, from: Data(text[start...end].utf8))
    }

    static func expand(_ note: String, with r: AIRequest) async throws -> Expansion {
        let result: Expansion
        switch r.provider {
        case .apple: result = try await AppleModel.expand(note)
        case .claude: result = try await ClaudeCLI.expand(note, model: r.model)
        case .codex: result = try await CodexCLI.expand(note, model: r.model)
        case .gemini: result = try await GeminiCLI.expand(note, model: r.model)
        case .ollama:
            guard !r.model.isEmpty else { throw AIError.noModel }
            result = try await OllamaClient(url: r.ollamaURL).expand(note, model: r.model)
        }
        guard !result.items.isEmpty else { throw AIError.empty }
        return result
    }

    /// Nil when the provider is ready, otherwise what the user needs to do.
    static func problem(_ p: Provider) async -> String? {
        switch p {
        case .apple: return AppleModel.unavailableReason
        case .ollama: return nil
        case .claude, .codex, .gemini:
            guard let tool = p.tool, await Task.detached(operation: { CLI.find(tool) }).value != nil else { return "Not installed" }
            let loggedIn = switch p {
            case .claude: await ClaudeCLI.loggedIn()
            case .codex: await CodexCLI.loggedIn()
            default: true // Gemini CLI has no status command; errors show on first use.
            }
            return loggedIn ? nil : "Not signed in"
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

    static func json(_ url: URL, body: [String: Any]? = nil) throws -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpMethod = "POST"
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    /// OpenAI-compatible servers nest a `message` under `error`.
    private static func message(from data: Data) -> String {
        struct Wrapped: Decodable { struct E: Decodable { let message: String }; let error: E }
        if let w = try? JSONDecoder().decode(Wrapped.self, from: data) { return w.error.message }
        return String(decoding: data.prefix(300), as: UTF8.self)
    }
}
