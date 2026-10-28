import SwiftUI

struct CaptureView: View {
    let onSubmit: (String) -> Void

    @Environment(AppSettings.self) private var settings
    @State private var text = ""
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
                Label(settings.activeLabel, systemImage: settings.provider.symbol)
                Spacer()
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
    }
}
