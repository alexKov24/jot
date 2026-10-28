import KeyboardShortcuts
import SwiftUI

struct IdeasView: View {
    @Environment(IdeaStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ideas").font(.title2.bold())
                Spacer()
                Text("\(store.ideas.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
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
                ContentUnavailableView(
                    "No ideas yet",
                    systemImage: "lightbulb",
                    description: Text("Press \(KeyboardShortcuts.getShortcut(for: .capture)?.description ?? "your shortcut") to capture one.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.ideas) { IdeaCard(idea: $0) }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .frame(width: 440, height: 600)
        .background(.regularMaterial)
    }
}

private struct IdeaCard: View {
    let idea: Idea
    @Environment(IdeaStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(idea.title).font(.headline)
                Spacer()
                status
            }
            if idea.title != idea.note {
                Text(idea.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            ForEach(idea.items) { item in
                Toggle(isOn: Binding(get: { item.done }, set: { _ in store.toggle(item.id) })) {
                    Text(item.text)
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
                .foregroundStyle(.secondary)
        }
    }

    private func copy() {
        let lines = ["## \(idea.title)", ""] + idea.items.map { "- [\($0.done ? "x" : " ")] \($0.text)" }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
}
