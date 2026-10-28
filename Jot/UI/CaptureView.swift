import SwiftUI

struct CaptureView: View {
    let onSubmit: (String) -> Void

    @Environment(AppSettings.self) private var settings
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "lightbulb.max")
                    .font(.title2)
                    .foregroundStyle(.tint)
                TextField("What's the idea?", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .lineLimit(1...4)
                    .focused($focused)
                    .onSubmit { onSubmit(text) }
            }
            HStack {
                Label(settings.activeLabel, systemImage: settings.provider.symbol)
                Spacer()
                Text("↩ save   esc close")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(width: 580)
        .background(.regularMaterial)
        // onAppear runs before the panel is key, so focus would be dropped.
        .defaultFocus($focused, true)
        .onAppear { DispatchQueue.main.async { focused = true } }
    }
}
