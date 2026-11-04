import SwiftUI
import TemizCacheCore

struct UpdatesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter: UpdateFilter = .all
    @State private var searchText: String = ""
    @State private var isExceptionsExpanded: Bool = false

    enum UpdateFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case apps = "Apps"
        case packages = "Packages"
        case system = "System & Store"

        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard

                if model.isApplyingUpdates {
                    activeProgressCard
                }

                if model.showUpdateLogs {
                    consoleDrawer
                }

                filterAndActionsBar

                if filteredItems.isEmpty {
                    emptyState
                } else {
                    updatesList
                }

                if !model.ignoredUpdates.isEmpty {
                    exceptionsSection
                }
            }
            .padding(24)
        }
        .background(Theme.canvas)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.85), Color.teal.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("App & Package Updates")
                        .font(.title2.weight(.bold))
                    if model.availableUpdatesCount > 0 {
                        Text("\(model.availableUpdatesCount)")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.18))
                            .foregroundStyle(Theme.accent)
                            .clipShape(Capsule())
                    }
                }

                Text("Checks original sources of installed apps, Homebrew casks & formulae, App Store apps, and macOS updates.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let last = model.lastUpdateCheckDate {
                    Text("Last checked: \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 1)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    Task { await model.checkForUpdates() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(model.isCheckingUpdates ? 360 : 0))
                            .animation(model.isCheckingUpdates ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: model.isCheckingUpdates)
                        Text(model.isCheckingUpdates ? "Checking…" : "Check Now")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .disabled(model.isCheckingUpdates || model.isApplyingUpdates)

                Button {
                    model.requestUpdateAll()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Update All (\(model.availableUpdatesCount))")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(model.availableUpdatesCount == 0 || model.isApplyingUpdates)

                Button {
                    model.showUpdateLogs.toggle()
                } label: {
                    Image(systemName: "terminal")
                        .help("Toggle console output log")
                }
                .padding(.vertical, 6)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Active Progress Card

    private var activeProgressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ProgressView()
                    .controlSize(.small)
                if let p = model.updateProgress {
                    Text("Updating \(p.currentName) (\(p.completed)/\(p.total))…")
                        .font(.headline)
                    Spacer()
                    Text("\(Int((Double(p.completed) / Double(p.total)) * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Updating packages…")
                        .font(.headline)
                    Spacer()
                }
            }

            if let p = model.updateProgress {
                ProgressView(value: Double(p.completed), total: Double(p.total))
                    .tint(Theme.accent)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.accent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Console Output Drawer

    private var consoleDrawer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Terminal Output Log", systemImage: "terminal.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") {
                    model.clearUpdateLogs()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                Button {
                    model.showUpdateLogs = false
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(model.updateLogs.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(colorForLog(line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(10)
                }
                .frame(height: 180)
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onChange(of: model.updateLogs.count) {
                    if let lastIndex = model.updateLogs.indices.last {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
    }

    private func colorForLog(_ line: String) -> Color {
        if line.contains("❌") || line.contains("Error") || line.contains("failed") {
            return .red
        } else if line.contains("✅") || line.contains("Successfully") {
            return .green
        } else if line.contains("🚀") || line.contains("==>") {
            return .cyan
        } else if line.contains("$") {
            return .yellow
        }
        return .white.opacity(0.85)
    }

    // MARK: - Filter and Actions Bar

    private var filterAndActionsBar: some View {
        HStack(spacing: 12) {
            Picker("Filter", selection: $filter) {
                ForEach(UpdateFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 340)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search updates…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.cardBackground)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )

            Spacer()

            Button("Select All") {
                model.selectAllUpdates(true)
            }
            .font(.caption)
            .buttonStyle(.link)

            Button("Deselect All") {
                model.selectAllUpdates(false)
            }
            .font(.caption)
            .buttonStyle(.link)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 46))
                .foregroundStyle(.teal)

            Text("Everything is up to date")
                .font(.title3.weight(.bold))

            Text("No software or package updates are currently available. Check back later or trigger a rescan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button("Check Again") {
                Task { await model.checkForUpdates() }
            }
            .buttonStyle(.bordered)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardBackground)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Updates List

    private var updatesList: some View {
        VStack(spacing: 8) {
            ForEach(filteredItems) { item in
                updateRow(for: item)
            }
        }
    }

    private func updateRow(for item: SoftwareUpdateItem) -> some View {
        let isSelected = model.selectedUpdateIDs.contains(item.id)
        let isUpdating = model.updatingItemIDs.contains(item.id)
        let isUpdated = model.updatedItemIDs.contains(item.id)
        let error = model.failedItemErrors[item.id]

        return HStack(spacing: 14) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in model.toggleSelectUpdate(id: item.id) }
            ))
            .labelsHidden()
            .disabled(isUpdating || isUpdated)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color(for: item.source).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: item.source.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color(for: item.source))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.displayName)
                        .font(.body.weight(.semibold))
                    sourceBadge(for: item.source)
                }

                HStack(spacing: 6) {
                    Text(item.installedVersion)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                    Text(item.latestVersion)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }

            Spacer()

            if isUpdating {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Updating…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if isUpdated {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Updated")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            } else if let error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Failed")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }
                .help(error)
            } else {
                Button("Update") {
                    model.requestUpdateItem(item)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.isApplyingUpdates)
            }

            Menu {
                Button("Ignore updates for this item") {
                    model.toggleIgnoreUpdate(id: item.id)
                }
                Button("Copy name") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.name, forType: .string)
                }
                if let path = item.appBundlePath {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
    }

    private func sourceBadge(for source: UpdateSource) -> some View {
        Text(source.shortTitle)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color(for: source).opacity(0.16))
            .foregroundStyle(color(for: source))
            .clipShape(Capsule())
    }

    private func color(for source: UpdateSource) -> Color {
        switch source {
        case .brewCask: return .indigo
        case .brewFormula: return .orange
        case .mas: return .blue
        case .system: return .purple
        case .sparkle: return .teal
        case .npm: return .pink
        case .pip: return .green
        }
    }

    // MARK: - Exceptions Section

    private var exceptionsSection: some View {
        DisclosureGroup(
            isExpanded: $isExceptionsExpanded,
            content: {
                VStack(spacing: 8) {
                    ForEach(model.ignoredUpdates) { item in
                        HStack {
                            Image(systemName: item.source.systemImage)
                                .foregroundStyle(.secondary)
                            Text(item.displayName)
                                .font(.subheadline)
                            Spacer()
                            Button("Unignore") {
                                model.toggleIgnoreUpdate(id: item.id)
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
                .padding(.top, 8)
            },
            label: {
                HStack {
                    Text("Update exceptions (\(model.ignoredUpdates.count))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        )
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardBackground)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Filter Logic

    private var filteredItems: [SoftwareUpdateItem] {
        var items = model.availableUpdates

        switch filter {
        case .all:
            break
        case .apps:
            items = items.filter { $0.source.isApplication }
        case .packages:
            items = items.filter { $0.source == .brewFormula || $0.source == .npm || $0.source == .pip }
        case .system:
            items = items.filter { $0.source == .system || $0.source == .mas }
        }

        if !searchText.isEmpty {
            items = items.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        return items
    }
}
