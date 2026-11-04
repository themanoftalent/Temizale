import SwiftUI
import TemizCacheCore

struct CategoryView: View {
    @EnvironmentObject private var model: AppModel
    let kind: CacheTarget.Kind

    var body: some View {
        let rows = model.rows(for: kind)
        Page(title: kind.title, subtitle: subtitle) {
            HStack(spacing: 12) {
                Button(model.allSelected(kind: kind) ? "Deselect All" : "Select All") {
                    model.setSelected(!model.allSelected(kind: kind), kind: kind)
                }
                .disabled(model.cleaning != nil)
                Picker("Sort by", selection: $model.sortOrder) {
                    ForEach(AppModel.SortOrder.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        } content: {
            if rows.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to show", systemImage: "checkmark.seal")
                } description: {
                    Text(model.hideEmptyLocations
                         ? "All locations here are empty. Turn off “Hide empty locations” in Settings to list them."
                         : "No locations in this category.")
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(rows) { row in
                        ItemCard(row: row)
                    }
                }
                .animation(.snappy, value: rows.map(\.id))
            }
        }
    }

    private var subtitle: String {
        let all = model.rows.filter { $0.target.kind == kind }
        return "\(ByteText.string(model.bytes(for: kind))) in \(all.count) location(s)"
    }
}

struct SearchResultsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let results = model.searchResults
        Page(title: "Search", subtitle: "\(results.count) result(s) for “\(model.searchText)”") {
            if results.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
                    .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(results) { ItemCard(row: $0) }
                }
            }
        }
    }
}
