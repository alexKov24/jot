import AppIntents
import SwiftUI
import WidgetKit

@main
struct JotWidgetBundle: WidgetBundle {
    var body: some Widget { IdeasWidget() }
}

struct IdeasWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Ideas", provider: IdeasTimeline()) { entry in
            IdeasWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Ideas")
        .description("Your latest ideas and their next steps.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct IdeasEntry: TimelineEntry {
    let date: Date
    let ideas: [Idea]
}

/// The app reloads timelines on every change, so no refresh schedule is needed.
struct IdeasTimeline: TimelineProvider {
    func placeholder(in context: Context) -> IdeasEntry {
        IdeasEntry(date: .now, ideas: [
            Idea(note: "", title: "Laravel + Inertia vs Next.js", items: [
                ChecklistItem(text: "Scaffold Laravel 12 with Inertia + React"),
                ChecklistItem(text: "Build the same CRUD page in Next.js"),
            ], status: .ready),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (IdeasEntry) -> Void) {
        let ideas = AppGroup.readSnapshot()
        completion(ideas.isEmpty && context.isPreview ? placeholder(in: context) : IdeasEntry(date: .now, ideas: ideas))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IdeasEntry>) -> Void) {
        completion(Timeline(entries: [IdeasEntry(date: .now, ideas: AppGroup.readSnapshot())], policy: .never))
    }
}

struct ToggleItem: AppIntent {
    static let title: LocalizedStringResource = "Toggle Checklist Item"

    @Parameter(title: "Item ID") var itemID: String

    init() {}
    init(_ id: UUID) { itemID = id.uuidString }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: itemID) { AppGroup.toggle(id) }
        return .result()
    }
}

struct IdeasWidgetView: View {
    let entry: IdeasEntry
    @Environment(\.widgetFamily) private var family

    private var rowBudget: Int { family == .systemLarge ? 12 : 5 }

    /// Ideas with open items, trimmed to fit: each idea costs one row for its title plus one per item.
    private var rows: [(idea: Idea, items: [ChecklistItem])] {
        var left = rowBudget
        var result: [(Idea, [ChecklistItem])] = []
        for idea in entry.ideas where !idea.openItems.isEmpty || idea.status != .ready {
            guard left >= 2 || (left >= 1 && idea.openItems.isEmpty) else { break }
            let items = Array(idea.openItems.prefix(left - 1))
            result.append((idea, items))
            left -= 1 + items.count
        }
        return result
    }

    var body: some View {
        if rows.isEmpty {
            VStack(spacing: 6) {
                PixelJ(cell: 3)
                Text("All clear").font(.headline)
                Text("Capture an idea from the menu bar.").font(.caption).foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(rows, id: \.idea.id) { row in
                    Text(row.idea.title)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                        .padding(.top, row.idea.id == rows.first?.idea.id ? 0 : 4)
                    ForEach(row.items) { item in
                        Button(intent: ToggleItem(item.id)) {
                            Label {
                                Text(item.text).lineLimit(1)
                            } icon: {
                                Image(systemName: "circle").foregroundStyle(Color.amber)
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
