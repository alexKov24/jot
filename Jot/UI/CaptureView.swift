import SwiftUI

struct CaptureView: View {
    let onSubmit: (String) -> Void

    @Environment(AppSettings.self) private var settings
    @State private var text = ""
    @State private var dictation = Dictation()
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                PixelJ()
                TextField("What's the idea?", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .lineLimit(1...4)
                    .focused($focused)
                    .onSubmit { onSubmit(text) }
            }
            HStack(spacing: 5) {
                if let message = dictation.message {
                    Label(message, systemImage: "mic").lineLimit(1)
                } else {
                    Label(settings.activeLabel, systemImage: settings.provider.symbol)
                }
                Spacer()
                Button(action: toggleDictation) {
                    HStack(spacing: 5) {
                        Image(systemName: dictation.isRecording ? "mic.fill" : "mic")
                        Keycap(key: "⌘D")
                        Text(dictation.isRecording ? "stop" : "dictate")
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(dictation.isRecording ? AnyShapeStyle(Color.amber) : AnyShapeStyle(.tertiary))
                .keyboardShortcut("d")
                .padding(.trailing, 6)
                Keycap(key: "↩")
                Text("save").padding(.trailing, 6)
                Keycap(key: "esc")
                Text("close")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(width: 580)
        .tint(.amber)
        .modifier(PanelChrome())
        // onAppear runs before the panel is key, so focus would be dropped.
        .defaultFocus($focused, true)
        .onAppear { DispatchQueue.main.async { focused = true } }
        // Turn the mic off when the panel closes (save, esc or losing focus).
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            if note.object is FloatingPanel { dictation.stop() }
        }
    }

    /// Dictated words go after whatever is already typed.
    private func toggleDictation() {
        let typed = text.isEmpty || text.hasSuffix(" ") ? text : text + " "
        dictation.toggle { text = typed + $0 }
    }
}
