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
    private(set) var connected: Set<Provider> = []

    private init() {
        provider = Provider(rawValue: defaults.string(forKey: "provider") ?? "") ?? .anthropic
        chosenModels = defaults.dictionary(forKey: "models.chosen") as? [String: String] ?? [:]
        modelLists = defaults.dictionary(forKey: "models.lists") as? [String: [String]] ?? [:]
        ollamaURL = defaults.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        connected = Set(Provider.allCases.filter { !$0.needsKey || Keychain.get($0.rawValue) != nil })
    }

    func model(for p: Provider) -> String { chosenModels[p.rawValue] ?? p.defaultModel }
    func setModel(_ model: String, for p: Provider) { chosenModels[p.rawValue] = model }
    func models(for p: Provider) -> [String] { modelLists[p.rawValue] ?? [] }

    /// Verifies credentials by listing models, then stores the key and the list.
    func connect(_ p: Provider, key: String?) async throws {
        let list = try await AI.models(request(for: p, key: key))
        if p.needsKey { Keychain.set(key, for: p.rawValue) }
        modelLists[p.rawValue] = list
        if !list.contains(model(for: p)), let first = list.first { setModel(first, for: p) }
        connected.insert(p)
    }

    func disconnect(_ p: Provider) {
        Keychain.set(nil, for: p.rawValue)
        modelLists[p.rawValue] = nil
        connected.remove(p)
    }

    func request(for p: Provider? = nil, key: String? = nil) -> AIRequest {
        let p = p ?? provider
        return AIRequest(provider: p, model: model(for: p), key: key ?? Keychain.get(p.rawValue), ollamaURL: ollamaURL)
    }

    /// Short label of the active model for the capture panel.
    var activeLabel: String {
        provider == .apple ? provider.name : "\(provider.name) · \(model(for: provider))"
    }
}
