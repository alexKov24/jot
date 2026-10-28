import KeyboardShortcuts
import SwiftUI

struct IdeasView: View {
    let onClose: () -> Void

    @Environment(IdeaStore.self) private var store
    @State private var searching = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var shown: [Idea] {
        guard !query.isEmpty else { return store.ideas }
        return store.ideas.filter { idea in
            ([idea.title, idea.note] + idea.items.map(\.text)).contains { $0.localizedStandardContains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                PixelJ()
                if searching {
                    TextField("Search ideas", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($searchFocused)
                        .onExitCommand(perform: closeSearch)
                } else {
                    Text("Ideas").font(.title2.bold())
                    Spacer()
                }
                Text("\(shown.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Color.amber)
                HeaderButton(symbol: searching ? "xmark.circle.fill" : "magnifyingglass") {
                    searching ? closeSearch() : openSearch()
                }
                .keyboardShortcut("f")
                HeaderButton(symbol: "xmark", action: onClose)
            }
            .animation(.snappy(duration: 0.2), value: searching)
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 12)

            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            if store.ideas.isEmpty {
                ContentUnavailableView {
                    Label { Text("No ideas yet") } icon: { PixelJ(cell: 4) }
                } description: {
                    Text("Press \(KeyboardShortcuts.getShortcut(for: .capture)?.description ?? "your shortcut") to capture one.")
                }
                .frame(maxHeight: .infinity)
            } else if shown.isEmpty {
                ContentUnavailableView.search(text: query)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(shown) { IdeaCard(idea: $0, query: query) }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .frame(width: 440, height: 600)
        .tint(.amber)
        .modifier(PanelChrome())
    }

    private func openSearch() {
        searching = true
        DispatchQueue.main.async { searchFocused = true }
    }

    private func closeSearch() {
        query = ""
        searching = false
    }
}

private struct HeaderButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Marks every match of `query` in amber.
private func highlight(_ text: String, _ query: String) -> AttributedString {
    var result = AttributedString(text)
    guard !query.isEmpty else { return result }
    var start = result.startIndex
    while let range = result[start...].range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
        result[range].backgroundColor = .amber.opacity(0.35)
        start = range.upperBound
    }
    return result
}

private struct IdeaCard: View {
    let idea: Idea
    let query: String
    @Environment(IdeaStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(highlight(idea.title, query)).font(.headline)
                Spacer()
                if let date = idea.remindAt {
                    Label(date.formatted(Calendar.current.isDateInToday(date) ? .dateTime.hour().minute() : .dateTime.weekday().hour().minute()), systemImage: "bell.fill")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.amber)
                }
                status
            }
            if idea.title != idea.note {
                Text(highlight(idea.note, query))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            ForEach(idea.items) { item in
                Toggle(isOn: Binding(get: { item.done }, set: { _ in store.toggle(item.id) })) {
                    Text(highlight(item.text, query))
                        .strikethrough(item.done)
                        .foregroundStyle(item.done ? .secondary : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.checkbox)
            }
            if let error = idea.error {
                HStack {
                    Text(error).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                    Button("Retry") { store.retry(idea.id) }.controlSize(.small)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.6), in: .rect(cornerRadius: 10))
        .contextMenu {
            Button("Expand Again") { store.retry(idea.id) }
            Button("Copy as Markdown") { copy() }
            Divider()
            Button("Delete", role: .destructive) { store.delete(idea.id) }
        }
    }

    @ViewBuilder private var status: some View {
        switch idea.status {
        case .expanding:
            ProgressView().controlSize(.small)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .ready:
            Text("\(idea.items.count - idea.openItems.count)/\(idea.items.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(idea.openItems.isEmpty ? AnyShapeStyle(Color.amber) : AnyShapeStyle(.secondary))
        }
    }

    private func copy() {
        let lines = ["## \(idea.title)", ""] + idea.items.map { "- [\($0.done ? "x" : " ")] \($0.text)" }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
}
