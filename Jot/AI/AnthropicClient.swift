import Foundation

/// Claude Messages API over raw HTTP (there is no official Swift SDK).
struct AnthropicClient {
    let key: String

    private static let base = URL(string: "https://api.anthropic.com/v1/")!
    /// Models that accept the server-side refusal fallback.
    private static let fallbackModels: Set = ["claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5", "claude-fable-5-1"]

    private var headers: [String: String] {
        ["x-api-key": key, "anthropic-version": "2026-10-21"]
    }

    func expand(_ note: String, model: String) async throws -> Expansion {
        struct Response: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
            let stop_reason: String?
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "system": AI.instructions,
            "messages": [["role": "user", "content": note]],
            "output_config": [
                "effort": "low",
                "format": ["type": "json_schema", "schema": AI.schema()],
            ],
        ]
        var headers = headers
        if Self.fallbackModels.contains(model) {
            body["fallbacks"] = "default"
            headers["anthropic-beta"] = "server-side-fallback-2026-07-01"
        }

        let request = try HTTP.json(Self.base.appending(path: "messages"), body: body, headers: headers)
        let response = try await HTTP.send(request, as: Response.self)
        if response.stop_reason == "refusal" { throw AIError.refused }
        guard let text = response.content.first(where: { $0.type == "text" })?.text else { throw AIError.empty }
        return try JSONDecoder().decode(Expansion.self, from: Data(text.utf8))
    }

    func models() async throws -> [String] {
        struct Response: Decodable { struct Model: Decodable { let id: String }; let data: [Model] }
        let url = Self.base.appending(path: "models").appending(queryItems: [.init(name: "limit", value: "100")])
        let request = try HTTP.json(url, headers: headers)
        return try await HTTP.send(request, as: Response.self).data.map(\.id)
    }
}
