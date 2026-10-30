import AppKit
import Observation

/// Checks GitHub for a newer release on launch, then daily. Only points at the release page.
@MainActor @Observable
final class Updates {
    static let shared = Updates()

    struct Release: Decodable {
        let tag: String
        let url: URL

        enum CodingKeys: String, CodingKey { case tag = "tag_name", url = "html_url" }

        var version: String { tag.hasPrefix("v") ? String(tag.dropFirst()) : tag }
    }

    /// The latest release, if it is newer than this build.
    private(set) var available: Release?

    private static let url = URL(string: "https://api.github.com/repos/alexKov24/jot/releases/latest")!
    private static let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    private init() {}

    func start() {
        Task {
            while true {
                _ = try? await check()
                try? await Task.sleep(for: .seconds(24 * 60 * 60))
            }
        }
    }

    /// Returns the newer release, or nil. A 404 means nothing is published yet.
    func check() async throws -> Release? {
        var request = URLRequest(url: Self.url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { available = nil; return nil }
        guard status == 200 else { throw URLError(.badServerResponse) }
        let release = try JSONDecoder().decode(Release.self, from: data)
        available = Self.isNewer(release.version, than: Self.current) ? release : nil
        return available
    }

    /// Menu action: opens the release page, or says Jot is up to date or the check failed.
    func checkNow() async {
        let alert = NSAlert()
        do {
            if let release = try await check() {
                NSWorkspace.shared.open(release.url)
                return
            }
            alert.messageText = "Jot is up to date"
            alert.informativeText = "You have version \(Self.current)."
        } catch {
            alert.messageText = "Couldn't check for updates"
            alert.informativeText = error.localizedDescription
        }
        NSApp.activate()
        alert.runModal()
    }

    /// Numeric dotted compare: "0.10.0" is newer than "0.9.1"; missing parts count as 0.
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 } }
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
