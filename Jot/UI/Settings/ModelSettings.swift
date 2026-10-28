import SwiftUI

struct ModelSettings: View {
    @Environment(AppSettings.self) private var settings
    @State private var connectingOllama = false

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Active") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(Provider.allCases) { p in
                        Label(p.name, systemImage: p.symbol)
                            .tag(p)
                            .selectionDisabled(settings.problems[p] != nil)
                    }
                }
                if settings.provider != .apple {
                    ModelPicker(provider: settings.provider)
                }
                if let problem = settings.problems[settings.provider] {
                    Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
            }
            Section {
                ForEach(Provider.allCases) { p in
                    ProviderRow(provider: p) { connectingOllama = true }
                }
            } header: {
                Text("Providers")
            } footer: {
                HStack {
                    Text("Claude Code, Codex and Gemini CLI run in headless mode with their own sign-in. Jot stores no keys.")
                    Spacer()
                    Button("Check Again") { Task { await settings.check() } }
                        .disabled(settings.checking)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await settings.check() }
        .sheet(isPresented: $connectingOllama) { OllamaSheet() }
    }
}

private struct ModelPicker: View {
    let provider: Provider
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let selection = Binding(get: { settings.model(for: provider) }, set: { settings.setModel($0, for: provider) })
        let models = settings.models(for: provider)
        if models.isEmpty {
            TextField("Model", text: selection, prompt: Text(provider == .ollama ? "model id" : "CLI default"))
        } else {
            Picker("Model", selection: selection) {
                if provider != .ollama { Text("CLI default").tag("") }
                ForEach(models, id: \.self) { Text($0).tag($0) }
                if !selection.wrappedValue.isEmpty, !models.contains(selection.wrappedValue) {
                    Text(selection.wrappedValue).tag(selection.wrappedValue)
                }
            }
        }
    }
}

private struct ProviderRow: View {
    let provider: Provider
    let onConnectOllama: () -> Void
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack {
            Label(provider.name, systemImage: provider.symbol)
            Spacer()
            if provider == .ollama {
                Button(settings.models(for: provider).isEmpty ? "Connect…" : "Refresh…", action: onConnectOllama)
            } else if settings.checking && settings.problems[provider] == nil {
                ProgressView().controlSize(.small)
            } else if let problem = settings.problems[provider] {
                Text(problem).foregroundStyle(.secondary)
                if problem == "Not installed", let page = provider.installPage {
                    Link("Install", destination: page)
                } else if let command = provider.loginCommand {
                    Text("Run `\(command)` in Terminal").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            } else {
                Text(provider == .apple ? "Available" : "Ready").foregroundStyle(.secondary)
            }
        }
    }
}

/// Enter the Ollama URL, verify it by listing models, then save.
private struct OllamaSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Connect \(Provider.ollama.name)", systemImage: Provider.ollama.symbol).font(.title3.bold())

            TextField("Server URL", text: $url, prompt: Text("http://localhost:11434"))
            Text("Ollama must be running. Jot lists the models you've pulled.")
                .font(.caption).foregroundStyle(.secondary)

            if let error {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button {
                    Task { await verify() }
                } label: {
                    if busy { ProgressView().controlSize(.small) } else { Text("Verify & Save") }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(busy)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(20)
        .frame(width: 420)
        .onAppear { url = settings.ollamaURL }
    }

    private func verify() async {
        busy = true
        defer { busy = false }
        settings.ollamaURL = url.isEmpty ? "http://localhost:11434" : url
        do {
            try await settings.connectOllama()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
