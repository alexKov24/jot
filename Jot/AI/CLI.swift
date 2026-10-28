import Foundation

/// Runs the user's installed AI CLIs (Claude Code, Codex, Gemini CLI) in headless mode.
/// They use the CLI's own login, so Jot stores no keys.
enum CLI {
    /// PATH from the user's login shell. Apps launched from Finder only get /usr/bin:/bin.
    nonisolated static let path: String = {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let fallback = ["~/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
            .map { NSString(string: $0).expandingTildeInPath }.joined(separator: ":")
        guard let out = try? execute(URL(filePath: shell), ["-lic", "print -r -- \"@@$PATH@@\""], path: fallback, seconds: 10),
              let text = String(data: out.stdout, encoding: .utf8),
              let start = text.range(of: "@@"), let end = text.range(of: "@@", options: .backwards), start.upperBound < end.lowerBound
        else { return fallback }
        return String(text[start.upperBound..<end.lowerBound])
    }()

    /// Full path of `tool` on the login-shell PATH, or nil when it isn't installed.
    static func find(_ tool: String) -> URL? {
        path.split(separator: ":")
            .map { URL(filePath: String($0)).appending(path: tool) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Runs `tool` and returns stdout. Throws with stderr when it exits non-zero.
    static func run(_ tool: String, _ args: [String], seconds: Double = 180) async throws -> Data {
        try await Task.detached {
            guard let url = find(tool) else { throw AIError.unavailable("\(tool) isn't installed.") }
            let out = try execute(url, args, path: path, seconds: seconds)
            guard out.status == 0 else {
                // `claude -p --output-format json` reports errors in stdout's `result`.
                struct Failure: Decodable { let result: String }
                if let failure = try? JSONDecoder().decode(Failure.self, from: out.stdout) { throw AIError.cli(tool, failure.result) }
                let text = String(decoding: out.stderr.isEmpty ? out.stdout : out.stderr, as: UTF8.self)
                throw AIError.cli(tool, String(text.trimmingCharacters(in: .whitespacesAndNewlines).suffix(300)))
            }
            return out.stdout
        }.value
    }

    /// Exit status only, for login checks.
    static func succeeds(_ tool: String, _ args: [String]) async -> Bool {
        (try? await run(tool, args, seconds: 20)) != nil
    }

    private struct Output: Sendable { let status: Int32; let stdout: Data; let stderr: Data }

    /// Blocking. Runs in a scratch directory so the CLIs don't pick up a project.
    private nonisolated static func execute(_ url: URL, _ args: [String], path: String, seconds: Double) throws -> Output {
        let process = Process()
        process.executableURL = url
        process.arguments = args
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = path
        process.environment = env
        let stdout = Pipe(), stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice
        try process.run()

        let timer = DispatchWorkItem { process.terminate() }
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds, execute: timer)
        // Drain stderr on another thread so a full pipe can't block the process.
        nonisolated(unsafe) var errData = Data()
        let group = DispatchGroup()
        DispatchQueue.global().async(group: group) { errData = stderr.fileHandleForReading.readDataToEndOfFile() }
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()
        timer.cancel()
        return Output(status: process.terminationStatus, stdout: outData, stderr: errData)
    }
}

/// `claude -p` with structured output.
enum ClaudeCLI {
    static func expand(_ note: String, model: String) async throws -> Expansion {
        struct Response: Decodable { let is_error: Bool?; let result: String?; let structured_output: Expansion? }
        var args = [
            "-p", note,
            "--output-format", "json",
            "--json-schema", try AI.schemaJSON(),
            "--system-prompt", AI.instructions,
            "--tools", "",
            "--effort", "low",
            "--no-session-persistence",
        ]
        if !model.isEmpty { args += ["--model", model] }
        let response = try JSONDecoder().decode(Response.self, from: try await CLI.run("claude", args))
        if response.is_error == true { throw AIError.cli("claude", response.result ?? "unknown error") }
        guard let result = response.structured_output else { throw AIError.empty }
        return result
    }

    static func loggedIn() async -> Bool { await CLI.succeeds("claude", ["auth", "status"]) }
}

/// `codex exec` with an output schema. Its last message goes to stdout.
enum CodexCLI {
    static func expand(_ note: String, model: String) async throws -> Expansion {
        let schema = FileManager.default.temporaryDirectory.appending(path: "jot-schema-\(UUID().uuidString).json")
        try Data(try AI.schemaJSON().utf8).write(to: schema)
        defer { try? FileManager.default.removeItem(at: schema) }
        var args = ["exec", "--ephemeral", "--skip-git-repo-check", "-s", "read-only", "-c", "web_search=\"disabled\"", "--output-schema", schema.path]
        if !model.isEmpty { args += ["-m", model] }
        args.append("\(AI.instructions)\n\nNote:\n\(note)")
        return try AI.decode(try await CLI.run("codex", args))
    }

    static func loggedIn() async -> Bool { await CLI.succeeds("codex", ["login", "status"]) }
}

/// `gemini -p` with JSON output. No schema flag, so the prompt asks for JSON.
enum GeminiCLI {
    static func expand(_ note: String, model: String) async throws -> Expansion {
        struct Response: Decodable { let response: String }
        var args = ["--output-format", "json"]
        if !model.isEmpty { args += ["-m", model] }
        args += ["-p", "\(AI.instructions)\nReply with only JSON matching this schema: \(try AI.schemaJSON())\n\nNote:\n\(note)"]
        let response = try JSONDecoder().decode(Response.self, from: try await CLI.run("gemini", args))
        return try AI.decode(Data(response.response.utf8))
    }
}
