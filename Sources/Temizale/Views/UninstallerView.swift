import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TemizCacheCore

struct UninstallerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var mode: UninstallerMode = .apps
    @State private var searchText: String = ""
    @State private var isDropTargeted: Bool = false
    @State private var selectedAppID: String? = nil

    enum UninstallerMode: String, CaseIterable, Identifiable {
        case apps = "Applications"
        case brew = "Homebrew Packages"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            switch mode {
            case .apps:
                appsView
            case .brew:
                brewView
            }
        }
        .background(Theme.canvas)
        .onAppear {
            if model.installedApps.isEmpty {
                Task { await model.scanInstalledApps() }
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.85), Color.orange.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("App & Package Uninstaller")
                    .font(.title2.weight(.bold))
                Text("Deep clean applications, all leftover files, and Homebrew packages.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Mode", selection: $mode) {
                ForEach(UninstallerMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)

            Button {
                if mode == .apps {
                    Task { await model.scanInstalledApps() }
                } else {
                    Task { await model.scanBrewPackages() }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees((model.isScanningApps || model.isScanningBrewPackages) ? 360 : 0))
                    .animation((model.isScanningApps || model.isScanningBrewPackages) ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: model.isScanningApps || model.isScanningBrewPackages)
            }
            .help("Rescan installed items")
            .disabled(model.isScanningApps || model.isScanningBrewPackages || model.isUninstalling)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.cardBackground)
    }

    // MARK: - Applications Master-Detail View

    private var appsView: some View {
        HSplitView {
            // Left list of installed apps
            VStack(spacing: 0) {
                dropZone
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                searchAndFilterBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                if model.isScanningApps && model.installedApps.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Discovering installed apps…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    appsList
                }
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)

            // Right app detail / leftover checklist
            appDetailView
                .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Drag and Drop Zone

    private var dropZone: some View {
        HStack(spacing: 10) {
            Image(systemName: isDropTargeted ? "arrow.down.app.fill" : "square.and.arrow.down")
                .font(.system(size: 20))
                .foregroundStyle(isDropTargeted ? Theme.accent : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(isDropTargeted ? "Release to inspect application" : "Drop an App here or choose")
                    .font(.caption.weight(.semibold))
                Text("Supports any .app from Finder")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button("Choose…") {
                chooseAppFile()
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isDropTargeted ? Theme.accent.opacity(0.12) : Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isDropTargeted ? Theme.accent : Theme.cardBorder, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.pathExtension == "app" else { return }
                Task { @MainActor in
                    await model.inspectAppURL(url)
                    selectedAppID = url.path
                }
            }
            return true
        }
    }

    private func chooseAppFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Inspect"
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await model.inspectAppURL(url)
                selectedAppID = url.path
            }
        }
    }

    // MARK: - Search Bar

    private var searchAndFilterBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search installed apps…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Apps List

    private var appsList: some View {
        List(filteredApps, selection: $selectedAppID) { app in
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                    .resizable()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text("v\(app.version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                if app.brewCaskName != nil {
                    Text("Cask")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.indigo.opacity(0.15))
                        .foregroundStyle(Color.indigo)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 3)
            .tag(app.id)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .onChange(of: selectedAppID) {
            if let id = selectedAppID, let app = model.installedApps.first(where: { $0.id == id }) {
                Task { await model.inspectApp(app) }
            }
        }
    }

    private var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return model.installedApps
        }
        return model.installedApps.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - App Detail View

    @ViewBuilder
    private var appDetailView: some View {
        if let app = model.selectedApp {
            VStack(spacing: 0) {
                // Header details
                appInspectorHeader(app: app)
                Divider()

                if model.isInspectingApp {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Searching application support, caches, containers, and preferences…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Leftovers Checklist
                    leftoversList(app: app)
                    Divider()
                    bottomActionBar(app: app)
                }
            }
        } else {
            VStack(spacing: 14) {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary.opacity(0.6))

                Text("Select an App to Inspect & Uninstall")
                    .font(.title3.weight(.bold))

                Text("Pick an application from the list on the left, or drag & drop an app bundle to discover all of its leftover files.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func appInspectorHeader(app: InstalledApp) -> some View {
        HStack(spacing: 16) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                .resizable()
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(app.displayName)
                        .font(.title3.weight(.bold))
                    Text("v\(app.version)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    if let cask = app.brewCaskName {
                        Text("Homebrew: \(cask)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.18))
                            .foregroundStyle(Color.indigo)
                            .clipShape(Capsule())
                    }
                }

                if let id = app.bundleIdentifier {
                    Text(id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }

                Text("\(ByteText.string(app.totalBytes)) across \(app.leftovers.count) location(s)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(app.bundleURL.path, inFileViewerRootedAtPath: "")
            }
            .controlSize(.small)
        }
        .padding(18)
        .background(Theme.cardBackground)
    }

    private func leftoversList(app: InstalledApp) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(app.leftovers) { item in
                    leftoverRow(item: item)
                }
            }
            .padding(16)
        }
    }

    private func leftoverRow(item: AppLeftoverItem) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in model.toggleLeftover(id: item.id) }
            ))
            .labelsHidden()

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color(for: item.category).opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: item.category.systemImage)
                    .font(.system(size: 14))
                    .foregroundStyle(color(for: item.category))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                    Text(item.category.title)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(color(for: item.category).opacity(0.14))
                        .foregroundStyle(color(for: item.category))
                        .clipShape(Capsule())
                }

                Text(item.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            BytesText(bytes: item.bytes)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)

            Menu {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                }
                Button("Copy Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.path, forType: .string)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 16, height: 16)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
    }

    private func bottomActionBar(app: InstalledApp) -> some View {
        HStack(spacing: 16) {
            Button("Select All") {
                model.selectAllLeftovers(true)
            }
            .font(.caption)
            .buttonStyle(.link)

            Button("Deselect All") {
                model.selectAllLeftovers(false)
            }
            .font(.caption)
            .buttonStyle(.link)

            Spacer()

            Text("Selected: \(ByteText.string(app.selectedBytes)) (\(app.selectedCount) of \(app.leftovers.count) items)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Button {
                model.requestUninstallApp()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text("Uninstall App (\(ByteText.string(app.selectedBytes)))")
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.trash)
            .disabled(app.selectedCount == 0 || model.isUninstalling)
        }
        .padding(14)
        .background(Theme.cardBackground)
    }

    private func color(for category: LeftoverCategory) -> Color {
        switch category {
        case .bundle: return .blue
        case .applicationSupport: return .indigo
        case .caches: return .teal
        case .preferences: return .purple
        case .containers: return .orange
        case .savedState: return .cyan
        case .httpStoragesAndWebKit: return .green
        case .logs: return .gray
        case .launchAgents: return .yellow
        case .other: return .secondary
        }
    }

    // MARK: - Homebrew Packages View

    private var brewView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                searchAndFilterBar
                Spacer()
                Text("\(model.installedBrewPackages.count) installed packages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Theme.cardBackground)
            Divider()

            if model.isScanningBrewPackages && model.installedBrewPackages.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading Homebrew packages…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.installedBrewPackages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Homebrew packages found")
                        .font(.headline)
                    Button("Scan Homebrew") {
                        Task { await model.scanBrewPackages() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredBrewPackages) { pkg in
                    HStack(spacing: 12) {
                        Image(systemName: pkg.isCask ? "macwindow" : "shippingbox")
                            .foregroundStyle(pkg.isCask ? Color.indigo : Color.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pkg.name)
                                .font(.body.weight(.semibold))
                            Text(pkg.isCask ? "Homebrew Cask" : "Homebrew Formula")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Uninstall") {
                            model.uninstallBrewPackage(pkg, zap: false)
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)

                        if pkg.isCask {
                            Button("Zap…") {
                                model.uninstallBrewPackage(pkg, zap: true)
                            }
                            .controlSize(.small)
                            .buttonStyle(.bordered)
                            .tint(Theme.trash)
                            .help("Removes cask and deletes all related preferences and application files")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .onAppear {
            if model.installedBrewPackages.isEmpty {
                Task { await model.scanBrewPackages() }
            }
        }
    }

    private var filteredBrewPackages: [InstalledBrewPackage] {
        if searchText.isEmpty {
            return model.installedBrewPackages
        }
        return model.installedBrewPackages.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}
