import Foundation

/// Ollama through its OpenAI-compatible Chat Completions endpoint.
struct OllamaClient {
    private let base: URL

    init(url: String) {
        base = (URL(string: url) ?? URL(string: "http://localhost:11434")!).appending(path: "v1/")
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

        let request = try HTTP.json(base.appending(path: "chat/completions"), body: body)
        let message = try await HTTP.send(request, as: Response.self).choices.first?.message
        if message?.refusal != nil { throw AIError.refused }
        guard let text = message?.content else { throw AIError.empty }
        return try JSONDecoder().decode(Expansion.self, from: Data(text.utf8))
    }

    func models() async throws -> [String] {
        struct Response: Decodable { struct Model: Decodable { let id: String }; let data: [Model] }
        let request = try HTTP.json(base.appending(path: "models"))
        return try await HTTP.send(request, as: Response.self).data.map(\.id).sorted()
    }
}
