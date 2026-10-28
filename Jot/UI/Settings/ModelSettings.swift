import SwiftUI

struct ModelSettings: View {
    @Environment(AppSettings.self) private var settings
    @State private var connecting: Provider?

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Active") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(Provider.allCases) { p in
                        Label(p.name, systemImage: p.symbol)
                            .tag(p)
                            .selectionDisabled(!settings.connected.contains(p))
                    }
                }
                if settings.provider != .apple {
                    ModelPicker(provider: settings.provider)
                }
                if settings.provider == .apple, let reason = AppleModel.unavailableReason {
                    Label(reason, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
            }
            Section("Providers") {
                ForEach(Provider.allCases) { p in
                    ProviderRow(provider: p) { connecting = p }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $connecting) { ConnectSheet(provider: $0) }
    }
}

private struct ModelPicker: View {
    let provider: Provider
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let selection = Binding(get: { settings.model(for: provider) }, set: { settings.setModel($0, for: provider) })
        let models = settings.models(for: provider)
        if models.isEmpty {
            TextField("Model", text: selection, prompt: Text("model id"))
        } else {
            Picker("Model", selection: selection) {
                ForEach(models, id: \.self) { Text($0).tag($0) }
                if !models.contains(selection.wrappedValue) {
                    Text(selection.wrappedValue).tag(selection.wrappedValue)
                }
            }
        }
    }
}

private struct ProviderRow: View {
    let provider: Provider
    let onConnect: () -> Void
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack {
            Label(provider.name, systemImage: provider.symbol)
            Spacer()
            switch provider {
            case .apple:
                Text(AppleModel.unavailableReason == nil ? "Available" : "Unavailable")
                    .foregroundStyle(.secondary)
            case .ollama:
                Button(settings.models(for: provider).isEmpty ? "Connect…" : "Refresh…", action: onConnect)
            default:
                if settings.connected.contains(provider) {
                    Text("Connected").foregroundStyle(.secondary)
                    Button("Disconnect") { settings.disconnect(provider) }
                } else {
                    Button("Connect…", action: onConnect)
                }
            }
        }
    }
}

/// Paste a key (or Ollama URL), verify it by listing models, then save.
private struct ConnectSheet: View {
    let provider: Provider
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var url = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Connect \(provider.name)", systemImage: provider.symbol).font(.title3.bold())

            if provider == .ollama {
                TextField("Server URL", text: $url, prompt: Text("http://localhost:11434"))
                Text("Ollama must be running. Jot lists the models you've pulled.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                SecureField("API key", text: $key)
                HStack(spacing: 4) {
                    Text("Stored in your Keychain.")
                    if let page = provider.keyPage { Link("Get a key", destination: page) }
                }
                .font(.caption).foregroundStyle(.secondary)
            }

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
                .disabled(busy || (provider.needsKey && key.isEmpty))
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
        if provider == .ollama { settings.ollamaURL = url.isEmpty ? "http://localhost:11434" : url }
        do {
            try await settings.connect(provider, key: provider.needsKey ? key.trimmingCharacters(in: .whitespacesAndNewlines) : nil)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
