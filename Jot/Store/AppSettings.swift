import Foundation
import Observation

@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var provider: Provider {
        didSet { defaults.set(provider.rawValue, forKey: "provider") }
    }
    /// Chosen model per provider (keyed by provider raw value).
    private(set) var chosenModels: [String: String] {
        didSet { defaults.set(chosenModels, forKey: "models.chosen") }
    }
    /// Last fetched model list per provider.
    private(set) var modelLists: [String: [String]] {
        didSet { defaults.set(modelLists, forKey: "models.lists") }
    }
    var ollamaURL: String {
        didSet { defaults.set(ollamaURL, forKey: "ollamaURL") }
    }
    /// Editable part of the AI prompt. Saved only when it differs from `AI.defaultStyle`.
    var prompt: String {
        didSet {
            if prompt == AI.defaultStyle { defaults.removeObject(forKey: "prompt") } else { defaults.set(prompt, forKey: "prompt") }
        }
    }
    /// Why each provider can't run right now; missing means ready. Filled by `check()`.
    private(set) var problems: [Provider: String] = [:]
    private(set) var checking = false

    private init() {
        provider = Provider(rawValue: defaults.string(forKey: "provider") ?? "") ?? .claude
        chosenModels = defaults.dictionary(forKey: "models.chosen") as? [String: String] ?? [:]
        modelLists = defaults.dictionary(forKey: "models.lists") as? [String: [String]] ?? [:]
        ollamaURL = defaults.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        prompt = defaults.string(forKey: "prompt") ?? AI.defaultStyle
        Task { await check() }
    }

    func model(for p: Provider) -> String { chosenModels[p.rawValue] ?? "" }
    func setModel(_ model: String, for p: Provider) { chosenModels[p.rawValue] = model }
    func models(for p: Provider) -> [String] { modelLists[p.rawValue] ?? p.suggestedModels }

    /// Looks for each CLI on the login-shell PATH and asks it whether it's signed in.
    func check() async {
        checking = true
        defer { checking = false }
        await withTaskGroup(of: (Provider, String?).self) { group in
            for p in Provider.allCases { group.addTask { (p, await AI.problem(p)) } }
            for await (p, problem) in group { problems[p] = problem }
        }
    }

    /// Verifies the Ollama server by listing its models.
    func connectOllama() async throws {
        let list = try await OllamaClient(url: ollamaURL).models()
        modelLists[Provider.ollama.rawValue] = list
        if !list.contains(model(for: .ollama)), let first = list.first { setModel(first, for: .ollama) }
    }

    func request() -> AIRequest {
        AIRequest(provider: provider, model: model(for: provider), ollamaURL: ollamaURL, style: prompt)
    }

    /// Short label of the active model for the capture panel.
    var activeLabel: String {
        let model = model(for: provider)
        return provider == .apple || model.isEmpty ? provider.name : "\(provider.name) · \(model)"
    }
}
