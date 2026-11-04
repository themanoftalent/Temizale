import SwiftUI
import TemizCacheCore

struct TrashView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Page(title: "Trash", subtitle: "Files you deleted, plus caches AleTemizCache moved here") {
            summaryCard
            if model.trash?.readable == false { accessCard }
            infoCard
        }
        .task { await model.refreshTrash() }
    }

    private var summaryCard: some View {
        HStack(alignment: .center, spacing: 20) {
            IconBadge(symbol: isEmpty ? "trash" : "trash.fill", color: Theme.trash, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                if model.isCheckingTrash && model.trash == nil {
                    ProgressView().controlSize(.small)
                } else if let trash = model.trash, trash.readable {
                    BytesText(bytes: trash.bytes)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(trash.itemCount == 0 ? "The Trash is empty" : "\(trash.itemCount) item(s) in the Trash")
                        .foregroundStyle(.secondary)
                } else {
                    Text(model.trashFinderCount.map { "\($0) item(s)" } ?? "Size unknown")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(model.trashFinderCount == nil
                         ? "macOS hides the Trash folder from apps without Full Disk Access."
                         : "Counted by Finder. Grant Full Disk Access to see the size.")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 10) {
                Button(role: .destructive) {
                    model.requestEmptyTrash()
                } label: {
                    if model.isEmptyingTrash {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Emptying…")
                        }
                    } else {
                        Label("Empty Trash…", systemImage: "trash.slash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.trash)
                .controlSize(.large)
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .disabled(isEmpty || model.isBusy)
                .help("Permanently delete everything in the Trash (⇧⌘⌫)")

                HStack(spacing: 12) {
                    Button("Open in Finder") { model.openTrashInFinder() }
                        .buttonStyle(.link)
                    Button("Refresh") { Task { await model.refreshTrash() } }
                        .buttonStyle(.link)
                        .disabled(model.isCheckingTrash)
                }
                .font(.callout)
            }
        }
        .card(padding: 22)
        .animation(.snappy, value: model.trash)
    }

    private var isEmpty: Bool {
        if let trash = model.trash, trash.readable { return trash.itemCount == 0 }
        if let count = model.trashFinderCount { return count == 0 }
        return false
    }

    private var accessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Measuring the Trash needs Full Disk Access", systemImage: "lock.shield")
                .font(.headline)
            Text("Emptying still works without it: AleTemizCache asks Finder to empty the Trash, and macOS asks you once to allow that. To see the size here, add AleTemizCache under System Settings › Privacy & Security › Full Disk Access, then click Refresh.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Open Full Disk Access Settings") { SystemSettings.open(.fullDiskAccess) }
                    .buttonStyle(.bordered)
                Button {
                    Task { await model.countTrashWithFinder() }
                } label: {
                    if model.isCheckingTrash { ProgressView().controlSize(.small) } else { Text("Count Items with Finder") }
                }
                .buttonStyle(.bordered)
                .disabled(model.isCheckingTrash)
            }
        }
        .card()
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Good to know")
            bullet("arrow.uturn.backward", "Caches cleaned in “Move to Trash” mode land here, so you can restore them until you empty the Trash.")
            bullet("externaldrive", "Emptying also clears Trash folders on connected external drives, as Finder does.")
            bullet("exclamationmark.triangle", "Emptying is permanent. AleTemizCache always asks before it empties.")
        }
        .card()
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.accent)
        }
        .foregroundStyle(.secondary)
    }
}
