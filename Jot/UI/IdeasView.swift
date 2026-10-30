import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

struct IdeasView: View {
    @Environment(IdeaStore.self) private var store
    @State private var dragging: UUID?
    @State private var searching = false
    @State private var query = ""
    @State private var showDeleted = false
    @FocusState private var searchFocused: Bool

    private var shown: [Idea] {
        let ideas = showDeleted ? store.deleted : store.ideas
        guard !query.isEmpty else { return ideas }
        return ideas.filter { idea in
            ([idea.title, idea.note] + idea.items.map(\.text)).contains { $0.localizedStandardContains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if searching {
                    TextField("Search ideas", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($searchFocused)
                        .onExitCommand(perform: closeSearch)
                } else {
                    PixelText("my jots")
                    if showDeleted {
                        Text("Recently Deleted").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text("\(shown.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Color.amber)
                HeaderButton(symbol: searching ? "xmark.circle.fill" : "magnifyingglass") {
                    searching ? closeSearch() : openSearch()
                }
                .keyboardShortcut("f")
                HeaderButton(symbol: showDeleted ? "trash.fill" : "trash") { showDeleted.toggle() }
                    .help(showDeleted ? "Back to jots" : "Recently Deleted")
            }
            .animation(.snappy(duration: 0.2), value: searching)
            .padding(.horizontal, 20)
            // Clear the traffic lights in the title bar.
            .padding(.leading, 76)
            .padding(.top, 13)
            .padding(.bottom, 12)

            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            if showDeleted && store.deleted.isEmpty {
                ContentUnavailableView("Nothing deleted", systemImage: "trash",
                                       description: Text("Deleted jots stay here for 30 days."))
                    .frame(maxHeight: .infinity)
            } else if !showDeleted && store.ideas.isEmpty {
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
                        if showDeleted {
                            ForEach(shown) { DeletedCard(idea: $0, query: query) }
                        } else {
                            ForEach(shown) { idea in
                                IdeaCard(idea: idea, query: query)
                                    .onDrag {
                                        dragging = idea.id
                                        return NSItemProvider(object: idea.title as NSString)
                                    }
                                    .onDrop(of: [.text], delegate: CardDrop(target: idea.id, dragging: $dragging, store: store))
                            }
                        }
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

/// A jot in Recently Deleted: restore it or delete it for good.
private struct DeletedCard: View {
    let idea: Idea
    let query: String
    @Environment(IdeaStore.self) private var store

    private var daysLeft: Int {
        let end = (idea.deletedAt ?? .now).addingTimeInterval(IdeaStore.keepDeleted)
        return max(Int(ceil(end.timeIntervalSinceNow / 86400)), 1)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(highlight(idea.title, query)).font(.headline).foregroundStyle(.secondary)
                Text(daysLeft == 1 ? "1 day left" : "\(daysLeft) days left")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Restore") { store.restore(idea.id) }.controlSize(.small)
            Button("Delete Now", role: .destructive) { store.deleteNow(idea.id) }.controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.6), in: .rect(cornerRadius: 10))
    }
}

/// Reorders live as a dragged card passes over the others.
private struct CardDrop: DropDelegate {
    let target: UUID
    @Binding var dragging: UUID?
    let store: IdeaStore

    func dropEntered(info: DropInfo) {
        guard let dragging else { return }
        withAnimation(.snappy(duration: 0.2)) { store.move(dragging, to: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
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

/// Renders inline Markdown (bold, italic, `code`, links, ~~strike~~) and marks every match of `query` in amber.
private func highlight(_ text: String, _ query: String) -> AttributedString {
    var result = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
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
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(highlight(idea.title, query)).font(.headline)
                Spacer()
                if let date = idea.remindAt {
                    Label(remindLabel(date, allDay: idea.remindAllDay == true), systemImage: "bell.fill")
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
            Button("Delete", role: .destructive) {
                if idea.reminderID == nil { store.delete(idea.id) } else { confirmDelete = true }
            }
        }
        .confirmationDialog("Delete calendar reminder?", isPresented: $confirmDelete) {
            Button("Delete Idea and Reminder", role: .destructive) { store.delete(idea.id, reminder: true) }
            Button("Delete Idea Only") { store.delete(idea.id) }
        } message: {
            Text("\"\(idea.title)\" also has a reminder in Apple Reminders.")
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

    private func remindLabel(_ date: Date, allDay: Bool) -> String {
        let today = Calendar.current.isDateInToday(date)
        if allDay { return today ? "Today" : date.formatted(.dateTime.weekday()) }
        return date.formatted(today ? .dateTime.hour().minute() : .dateTime.weekday().hour().minute())
    }

    private func copy() {
        let lines = ["## \(idea.title)", ""] + idea.items.map { "- [\($0.done ? "x" : " ")] \($0.text)" }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
}
