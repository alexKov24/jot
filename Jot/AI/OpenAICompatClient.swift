import Foundation

/// OpenAI Chat Completions shape. Also serves Gemini and Ollama through their OpenAI-compatible endpoints.
struct OpenAICompatClient {
    private let base: URL
    private let key: String?

    init(_ r: AIRequest) {
        switch r.provider {
        case .gemini: base = URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/")!
        case .ollama: base = (URL(string: r.ollamaURL) ?? URL(string: "http://localhost:11434")!).appending(path: "v1/")
        default: base = URL(string: "https://api.openai.com/v1/")!
        }
        key = r.key
    }

    private var headers: [String: String] {
        guard let key, !key.isEmpty else { return [:] }
        return ["Authorization": "Bearer \(key)"]
    }

    func expand(_ note: String, model: String) async throws -> Expansion {
        struct Response: Decodable {
            struct Choice: Decodable { struct Message: Decodable { let content: String?; let refusal: String? }; let message: Message }
            let choices: [Choice]
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": AI.instructions],
                ["role": "user", "content": note],
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": ["name": "checklist", "strict": true, "schema": AI.schema()],
            ],
        ]

        let request = try HTTP.json(base.appending(path: "chat/completions"), body: body, headers: headers)
        let message = try await HTTP.send(request, as: Response.self).choices.first?.message
        if message?.refusal != nil { throw AIError.refused }
        guard let text = message?.content else { throw AIError.empty }
        return try JSONDecoder().decode(Expansion.self, from: Data(text.utf8))
    }

    func models() async throws -> [String] {
        struct Response: Decodable { struct Model: Decodable { let id: String }; let data: [Model] }
        let request = try HTTP.json(base.appending(path: "models"), headers: headers)
        return try await HTTP.send(request, as: Response.self).data.map(\.id).sorted()
    }
}
