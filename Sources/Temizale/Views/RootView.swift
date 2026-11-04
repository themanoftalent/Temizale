import SwiftUI
import TemizCacheCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 320)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsActionBar { ActionBar() }
                }
                .overlay(alignment: .top) {
                    if let toast = model.toast {
                        ToastView(toast: toast)
                            .padding(.top, 10)
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(1)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.toast)
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search caches")
        .toolbar { toolbar }
        .tint(Theme.accent)
        .confirmationDialog(
            confirmTitle,
            isPresented: Binding(get: { model.pending != nil }, set: { if !$0 { model.pending = nil } }),
            titleVisibility: .visible,
            presenting: model.pending
        ) { action in
            Button(confirmButton(for: action), role: confirmRole(for: action)) { model.perform(action) }
            Button("Cancel", role: .cancel) { model.pending = nil }
        } message: { action in
            Text(confirmMessage(for: action))
        }
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            if !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                SearchResultsView()
            } else {
                switch model.selection ?? .overview {
                case .overview: OverviewView()
                case .updates: UpdatesView()
                case .category(let kind): CategoryView(kind: kind)
                case .trash: TrashView()
                case .history: HistoryView()
                }
            }
        }
        .id(detailID)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.18), value: detailID)
    }

    private var detailID: String {
        if !model.searchText.isEmpty { return "search" }
        switch model.selection ?? .overview {
        case .overview: return "overview"
        case .updates: return "updates"
        case .category(let kind): return "cat-\(kind.rawValue)"
        case .trash: return "trash"
        case .history: return "history"
        }
    }

    private var showsActionBar: Bool {
        switch model.selection ?? .overview {
        case .trash, .history, .updates: return !model.searchText.isEmpty
        default: return true
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task {
                    await model.refreshAll()
                    await model.checkForUpdates()
                }
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .help("Rescan caches and check for updates (⌘R)")
            .disabled(model.isBusy)
        }
    }

    // MARK: Confirmation text

    private var confirmTitle: String {
        guard let action = model.pending else { return "" }
        switch action {
        case .cleanSelected: return "Clean \(ByteText.string(model.selectedBytes))?"
        case .cleanTarget(let target): return "Clean \(target.title)?"
        case .emptyTrash: return "Empty the Trash?"
        case .clearHistory: return "Clear cleaning history?"
        case .updateAll: return "Update \(model.availableUpdatesCount) apps & packages?"
        case .updateItem(let item): return "Update \(item.displayName)?"
        }
    }

    private func confirmRole(for action: AppModel.PendingAction) -> ButtonRole? {
        switch action {
        case .cleanSelected, .cleanTarget, .emptyTrash, .clearHistory:
            return .destructive
        case .updateAll, .updateItem:
            return nil
        }
    }

    private func confirmButton(for action: AppModel.PendingAction) -> String {
        switch action {
        case .cleanSelected, .cleanTarget:
            return model.deletePermanently ? "Delete Permanently" : "Move to Trash"
        case .emptyTrash: return "Empty Trash"
        case .clearHistory: return "Clear History"
        case .updateAll: return "Update All"
        case .updateItem: return "Update"
        }
    }

    private func confirmMessage(for action: AppModel.PendingAction) -> String {
        let destination = model.deletePermanently
            ? "Contents are deleted immediately and cannot be restored."
            : "Contents move to the Trash, so you can still restore them."
        switch action {
        case .cleanSelected:
            let names = model.selectedRows.filter { ($0.size ?? 0) > 0 }.map(\.target.title)
            let list = names.prefix(5).joined(separator: ", ") + (names.count > 5 ? ", and \(names.count - 5) more" : "")
            return "\(list).\n\n\(destination) Quit the affected apps first for the best result."
        case .cleanTarget(let target):
            let size = model.row(target.id)?.size.map(ByteText.string) ?? "Unknown size"
            return "\(size) in \(target.paths.count) folder(s).\n\n\(destination)"
        case .emptyTrash:
            return "Everything in the Trash is permanently deleted, including files you deleted yourself and items in Trash folders on external drives. This cannot be undone."
        case .clearHistory:
            return "This removes the record of past cleanups. No files are affected."
        case .updateAll:
            return "This will upgrade all selected applications and packages through their original sources (Homebrew, Mac App Store, macOS system updater, etc.)."
        case .updateItem(let item):
            return "Upgrade \(item.displayName) from version \(item.installedVersion) to \(item.latestVersion) using \(item.source.title)."
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: $model.selection) {
            Section {
                row(.overview, title: "Overview", symbol: "gauge.with.dots.needle.67percent", color: Theme.accent, bytes: model.totalBytes)
                updatesRow
            }
            Section("Caches") {
                ForEach(model.kindsInUse, id: \.self) { kind in
                    row(.category(kind), title: kind.title, symbol: kind.symbol, color: Theme.color(for: kind), bytes: model.bytes(for: kind))
                }
            }
            Section("System") {
                row(.trash, title: "Trash", symbol: "trash", color: Theme.trash,
                    bytes: model.trash?.readable == true ? model.trash?.bytes : nil)
                row(.history, title: "History", symbol: "clock.arrow.circlepath", color: .gray, bytes: nil)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) { BrandHeader() }
        .safeAreaInset(edge: .bottom) { diskFooter }
    }

    private var updatesRow: some View {
        HStack(spacing: 10) {
            IconBadge(symbol: "shippingbox.and.arrow.backward", color: .teal, size: 22)
            Text("Updates")
                .lineLimit(1)
            Spacer(minLength: 4)
            if model.isCheckingUpdates {
                ProgressView()
                    .controlSize(.mini)
            } else if model.availableUpdatesCount > 0 {
                Text("\(model.availableUpdatesCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.teal)
                    .clipShape(Capsule())
            }
        }
        .tag(AppModel.SidebarItem.updates)
        .accessibilityElement(children: .combine)
    }

    private func row(_ item: AppModel.SidebarItem, title: String, symbol: String, color: Color, bytes: Int64?) -> some View {
        HStack(spacing: 10) {
            IconBadge(symbol: symbol, color: color, size: 22)
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            if let bytes, bytes > 0 {
                BytesText(bytes: bytes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .tag(item)
        .accessibilityElement(children: .combine)
    }

    private var diskFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let disk = model.disk {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "internaldrive").foregroundStyle(.secondary)
                        Text("Macintosh HD").font(.caption.weight(.medium))
                        Spacer()
                        Text("\(ByteText.string(disk.available)) free")
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    ProgressView(value: disk.usedFraction)
                        .tint(disk.usedFraction > 0.9 ? Theme.trash : Theme.accent)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Disk: \(ByteText.string(disk.available)) free of \(ByteText.string(disk.total))")
            }
            Text(Brand.credit)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
