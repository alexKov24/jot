import Foundation
import FoundationModels

/// Apple's on-device model via the Foundation Models framework. Free, offline, ~4K token context.
enum AppleModel {
    @Generable
    struct Plan {
        @Guide(description: "Short title, at most 8 words")
        var title: String
        @Guide(description: "3 to 8 concrete actions, each starting with a verb")
        var items: [String]
    }

    /// nil when ready, otherwise why it can't run.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available: nil
        case .unavailable(.deviceNotEligible): "This Mac doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled): "Turn on Apple Intelligence in System Settings."
        case .unavailable(.modelNotReady): "The model is still downloading."
        case .unavailable: "Apple Intelligence is unavailable."
        }
    }

    static func expand(_ note: String) async throws -> Expansion {
        if let reason = unavailableReason { throw AIError.unavailable(reason) }
        let session = LanguageModelSession(instructions: AI.instructions)
        let plan = try await session.respond(to: note, generating: Plan.self).content
        return Expansion(title: plan.title, items: plan.items)
    }
}
