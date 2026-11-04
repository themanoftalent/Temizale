import SwiftUI
import TemizCacheCore

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Page(title: "History", subtitle: "\(ByteText.string(model.history.lifetimeBytes)) freed in total") {
            Button("Clear History…", role: .destructive) { model.requestClearHistory() }
                .disabled(model.history.entries.isEmpty)
        } content: {
            if model.history.entries.isEmpty {
                ContentUnavailableView {
                    Label("No cleanups yet", systemImage: "clock")
                } description: {
                    Text("Each cleanup you run appears here with the space it freed.")
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(model.history.entries) { entry in
                        HStack(spacing: 14) {
                            IconBadge(symbol: entry.kind == .trash ? "trash.fill" : "sparkles",
                                      color: entry.kind == .trash ? Theme.trash : Theme.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.kind == .trash ? "Emptied the Trash" : "Cleaned \(entry.targets.count) location(s)")
                                    .font(.body.weight(.semibold))
                                Text(detail(entry))
                                    .font(.callout).foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                BytesText(bytes: entry.bytes)
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .card(padding: 14)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func detail(_ entry: CleanHistory.Entry) -> String {
        let items = "\(entry.items) item(s)"
        if entry.kind == .trash || entry.targets.isEmpty { return items }
        return "\(items) · \(entry.targets.joined(separator: ", "))"
    }
}
