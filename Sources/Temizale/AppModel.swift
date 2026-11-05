import Foundation
import AppKit
import TemizCacheCore

/// Single source of truth for the UI. All view state lives here rather than in
/// `@State`, which keeps the app buildable with the Command Line Tools toolchain.
@MainActor
final class AppModel: ObservableObject {
    // MARK: Types

    enum SidebarItem: Hashable {
        case overview
        case updates
        case uninstaller
        case category(CacheTarget.Kind)
        case trash
        case history
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case size, name
        var id: String { rawValue }
        var title: String { self == .size ? "Size" : "Name" }
    }

    enum PendingAction: Identifiable {
        case cleanSelected
        case cleanTarget(CacheTarget)
        case emptyTrash
        case clearHistory
        case updateAll
        case updateItem(SoftwareUpdateItem)
        case uninstallApp(InstalledApp)
        case uninstallBrewPackage(InstalledBrewPackage, zap: Bool)

        var id: String {
            switch self {
            case .cleanSelected: return "cleanSelected"
            case .cleanTarget(let t): return "clean-\(t.id)"
            case .emptyTrash: return "emptyTrash"
            case .clearHistory: return "clearHistory"
            case .updateAll: return "updateAll"
            case .updateItem(let item): return "updateItem-\(item.id)"
            case .uninstallApp(let app): return "uninstallApp-\(app.id)"
            case .uninstallBrewPackage(let pkg, let zap): return "uninstallBrew-\(pkg.id)-\(zap)"
            }
        }
    }

    struct Toast: Identifiable, Equatable {
        enum Style { case success, info, warning, error }
        enum Action: Equatable { case emptyTrash, openFullDiskAccess, openAutomation, showTrash }

        let id = UUID()
        let style: Style
        let title: String
        var detail: String?
        var action: Action?
        var actionTitle: String?
    }

    struct Row: Identifiable {
        let target: CacheTarget
        var size: Int64?
        var isSelected: Bool
        var id: String { target.id }
    }

    struct CleaningProgress: Equatable {
        var current: String
        var completed: Int
        var total: Int
        var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }
    }

    // MARK: Published state - Cache & Clean

    @Published private(set) var rows: [Row] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scannedCount = 0
    @Published private(set) var lastScan: Date?
    @Published private(set) var cleaning: CleaningProgress?
    @Published private(set) var disk: DiskSpace?
    @Published private(set) var trash: TrashInspector.Status?
    @Published private(set) var trashFinderCount: Int?
    @Published private(set) var isCheckingTrash = false
    @Published private(set) var isEmptyingTrash = false
    @Published private(set) var history = CleanHistory()
    @Published private(set) var warnings: [String] = []

    // MARK: Published state - Updates

    @Published private(set) var updateItems: [SoftwareUpdateItem] = []
    @Published private(set) var isCheckingUpdates = false
    @Published private(set) var isApplyingUpdates = false
    @Published private(set) var updatingItemIDs: Set<String> = []
    @Published private(set) var updatedItemIDs: Set<String> = []
    @Published private(set) var failedItemErrors: [String: String] = [:]
    @Published private(set) var lastUpdateCheckDate: Date?
    @Published private(set) var updateLogs: [String] = []
    @Published private(set) var updateProgress: (completed: Int, total: Int, currentName: String)?
    @Published var selectedUpdateIDs: Set<String> = []
    @Published var showUpdateLogs = false

    // MARK: Published state - Uninstaller

    @Published private(set) var installedApps: [InstalledApp] = []
    @Published var selectedApp: InstalledApp?
    @Published private(set) var isScanningApps = false
    @Published private(set) var isInspectingApp = false
    @Published private(set) var isUninstalling = false
    @Published private(set) var installedBrewPackages: [InstalledBrewPackage] = []
    @Published private(set) var isScanningBrewPackages = false

    // MARK: Navigation and UI

    @Published var selection: SidebarItem? = .overview
    @Published var searchText = ""
    @Published var sortOrder: SortOrder = .size {
        didSet { defaults.set(sortOrder.rawValue, forKey: Keys.sort) }
    }
    @Published var pending: PendingAction?
    @Published var toast: Toast?

    // Settings
    @Published var deletePermanently = false {
        didSet { defaults.set(deletePermanently, forKey: Keys.permanent) }
    }
    @Published var confirmBeforeCleaning = true {
        didSet { defaults.set(confirmBeforeCleaning, forKey: Keys.confirm) }
    }
    @Published var hideEmptyLocations = false {
        didSet { defaults.set(hideEmptyLocations, forKey: Keys.hideEmpty) }
    }

    // Update settings
    @Published var checkUpdatesOnLaunch = true {
        didSet { defaults.set(checkUpdatesOnLaunch, forKey: Keys.checkOnLaunch) }
    }
    @Published var checkHomebrewUpdates = true {
        didSet { defaults.set(checkHomebrewUpdates, forKey: Keys.checkBrew) }
    }
    @Published var checkMasUpdates = true {
        didSet { defaults.set(checkMasUpdates, forKey: Keys.checkMas) }
    }
    @Published var checkSystemUpdates = true {
        didSet { defaults.set(checkSystemUpdates, forKey: Keys.checkSystem) }
    }
    @Published var checkDevPackageUpdates = true {
        didSet { defaults.set(checkDevPackageUpdates, forKey: Keys.checkDev) }
    }
    @Published var checkSparkleUpdates = true {
        didSet { defaults.set(checkSparkleUpdates, forKey: Keys.checkSparkle) }
    }
    @Published var ignoredUpdateIDs: Set<String> = [] {
        didSet { defaults.set(Array(ignoredUpdateIDs), forKey: Keys.ignoredUpdates) }
    }

    // MARK: Private

    private enum Keys {
        static let permanent = "deletePermanently"
        static let confirm = "confirmBeforeCleaning"
        static let hideEmpty = "hideEmptyLocations"
        static let deselected = "deselectedTargetIDs"
        static let history = "cleanHistory"
        static let sort = "sortOrder"
        static let checkOnLaunch = "checkUpdatesOnLaunch"
        static let checkBrew = "checkHomebrewUpdates"
        static let checkMas = "checkMasUpdates"
        static let checkSystem = "checkSystemUpdates"
        static let checkDev = "checkDevPackageUpdates"
        static let checkSparkle = "checkSparkleUpdates"
        static let ignoredUpdates = "ignoredUpdateIDs"
    }

    private let defaults = UserDefaults.standard
    let home = FileManager.default.homeDirectoryForCurrentUser
    private var toastTask: Task<Void, Never>?

    // MARK: Init

    init() {
        deletePermanently = defaults.bool(forKey: Keys.permanent)
        confirmBeforeCleaning = defaults.object(forKey: Keys.confirm) as? Bool ?? true
        hideEmptyLocations = defaults.bool(forKey: Keys.hideEmpty)
        sortOrder = SortOrder(rawValue: defaults.string(forKey: Keys.sort) ?? "") ?? .size
        history = CleanHistory.decode(defaults.data(forKey: Keys.history))

        checkUpdatesOnLaunch = defaults.object(forKey: Keys.checkOnLaunch) as? Bool ?? true
        checkHomebrewUpdates = defaults.object(forKey: Keys.checkBrew) as? Bool ?? true
        checkMasUpdates = defaults.object(forKey: Keys.checkMas) as? Bool ?? true
        checkSystemUpdates = defaults.object(forKey: Keys.checkSystem) as? Bool ?? true
        checkDevPackageUpdates = defaults.object(forKey: Keys.checkDev) as? Bool ?? true
        checkSparkleUpdates = defaults.object(forKey: Keys.checkSparkle) as? Bool ?? true
        ignoredUpdateIDs = Set(defaults.stringArray(forKey: Keys.ignoredUpdates) ?? [])

        reloadCatalog()

        if checkUpdatesOnLaunch {
            Task { [weak self] in
                await self?.checkForUpdates()
            }
        }
    }

    // MARK: Derived values

    var isBusy: Bool { isScanning || cleaning != nil || isEmptyingTrash || isApplyingUpdates || isUninstalling }

    var totalBytes: Int64 { rows.compactMap(\.size).reduce(0, +) }

    var selectedRows: [Row] { rows.filter(\.isSelected) }

    var selectedBytes: Int64 { selectedRows.compactMap(\.size).reduce(0, +) }

    var selectedNonEmptyCount: Int { selectedRows.filter { ($0.size ?? 0) > 0 }.count }

    var kindsInUse: [CacheTarget.Kind] {
        CacheTarget.Kind.allCases.filter { kind in rows.contains { $0.target.kind == kind } }
    }

    var availableUpdates: [SoftwareUpdateItem] {
        updateItems.filter { !ignoredUpdateIDs.contains($0.id) && !updatedItemIDs.contains($0.id) }
    }

    var availableUpdatesCount: Int {
        availableUpdates.count
    }

    var ignoredUpdates: [SoftwareUpdateItem] {
        updateItems.filter { ignoredUpdateIDs.contains($0.id) }
    }

    func bytes(for kind: CacheTarget.Kind) -> Int64 {
        rows.filter { $0.target.kind == kind }.compactMap(\.size).reduce(0, +)
    }

    func rows(for kind: CacheTarget.Kind) -> [Row] {
        sorted(rows.filter { $0.target.kind == kind && visible($0) })
    }

    var searchResults: [Row] {
        let needle = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }
        return sorted(rows.filter { row in
            visible(row) && (row.target.title.lowercased().contains(needle)
                || row.target.summary.lowercased().contains(needle)
                || row.target.kind.title.lowercased().contains(needle)
                || row.target.paths.contains { $0.lowercased().contains(needle) })
        })
    }

    func row(_ id: String) -> Row? {
        rows.first { $0.id == id }
    }

    private func visible(_ row: Row) -> Bool {
        if hideEmptyLocations, let size = row.size, size == 0 { return false }
        return true
    }

    private func sorted(_ list: [Row]) -> [Row] {
        list.sorted { a, b in
            switch sortOrder {
            case .size:
                let sa = a.size ?? -1
                let sb = b.size ?? -1
                if sa != sb { return sa > sb }
                return a.target.title.localizedCaseInsensitiveCompare(b.target.title) == .orderedAscending
            case .name:
                return a.target.title.localizedCaseInsensitiveCompare(b.target.title) == .orderedAscending
            }
        }
    }

    // MARK: Catalog

    func reloadCatalog() {
        let result = Catalog.load(home: home)
        warnings = result.warnings
        let deselected = Set(defaults.stringArray(forKey: Keys.deselected) ?? [])
        let previousSizes = Dictionary(uniqueKeysWithValues: rows.compactMap { r in r.size.map { (r.id, $0) } })

        rows = result.targets.map { target in
            Row(target: target,
                size: previousSizes[target.id],
                isSelected: !deselected.contains(target.id))
        }
        Task { await refreshAll() }
    }

    func toggle(_ id: String) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].isSelected.toggle()
        persistSelection()
    }

    func setSelected(_ selected: Bool, kind: CacheTarget.Kind? = nil) {
        for i in rows.indices where kind == nil || rows[i].target.kind == kind {
            rows[i].isSelected = selected
        }
        persistSelection()
    }

    func allSelected(kind: CacheTarget.Kind) -> Bool {
        rows.filter { $0.target.kind == kind }.allSatisfy(\.isSelected)
    }

    private func persistSelection() {
        defaults.set(rows.filter { !$0.isSelected }.map(\.id), forKey: Keys.deselected)
    }

    // MARK: Cache Scanning

    func refreshAll() async {
        await scan()
        await refreshTrash()
    }

    func scan() async {
        guard !isScanning, cleaning == nil else { return }
        isScanning = true
        scannedCount = 0
        refreshDisk()

        let home = self.home
        let targets = rows.map(\.target)
        await withTaskGroup(of: (String, Int64).self) { group in
            for target in targets {
                group.addTask(priority: .utility) {
                    (target.id, SizeScanner.allocatedSize(of: target, home: home))
                }
            }
            for await (id, size) in group {
                if let index = rows.firstIndex(where: { $0.id == id }) {
                    rows[index].size = size
                }
                scannedCount += 1
            }
        }
        lastScan = Date()
        isScanning = false
    }

    private func measure(_ target: CacheTarget) async -> Int64 {
        let home = self.home
        return await Task.detached(priority: .userInitiated) {
            SizeScanner.allocatedSize(of: target, home: home)
        }.value
    }

    private func refreshDisk() {
        disk = DiskSpace.forVolume(containing: home)
    }

    // MARK: Software & Package Updates

    func checkForUpdates() async {
        guard !isCheckingUpdates, !isApplyingUpdates else { return }
        isCheckingUpdates = true
        let options = UpdateCheckOptions(
            checkBrew: checkHomebrewUpdates,
            checkMas: checkMasUpdates,
            checkSystem: checkSystemUpdates,
            checkSparkle: checkSparkleUpdates,
            checkDevPackages: checkDevPackageUpdates
        )
        let items = await SoftwareUpdateScanner.scan(options: options)
        self.updateItems = items
        self.selectedUpdateIDs = Set(items.filter { !self.ignoredUpdateIDs.contains($0.id) }.map(\.id))
        self.lastUpdateCheckDate = Date()
        self.isCheckingUpdates = false
    }

    func requestUpdateAll() {
        guard availableUpdatesCount > 0, !isApplyingUpdates else { return }
        if confirmBeforeCleaning {
            pending = .updateAll
        } else {
            perform(.updateAll)
        }
    }

    func requestUpdateItem(_ item: SoftwareUpdateItem) {
        guard !isApplyingUpdates else { return }
        if confirmBeforeCleaning {
            pending = .updateItem(item)
        } else {
            perform(.updateItem(item))
        }
    }

    func toggleIgnoreUpdate(id: String) {
        if ignoredUpdateIDs.contains(id) {
            ignoredUpdateIDs.remove(id)
            selectedUpdateIDs.insert(id)
        } else {
            ignoredUpdateIDs.insert(id)
            selectedUpdateIDs.remove(id)
        }
    }

    func toggleSelectUpdate(id: String) {
        if selectedUpdateIDs.contains(id) {
            selectedUpdateIDs.remove(id)
        } else {
            selectedUpdateIDs.insert(id)
        }
    }

    func selectAllUpdates(_ select: Bool) {
        if select {
            selectedUpdateIDs = Set(availableUpdates.map(\.id))
        } else {
            selectedUpdateIDs.removeAll()
        }
    }

    func appendUpdateLog(_ line: String) {
        updateLogs.append(line)
        if updateLogs.count > 600 {
            updateLogs.removeFirst(updateLogs.count - 600)
        }
    }

    func clearUpdateLogs() {
        updateLogs.removeAll()
    }

    func runInTerminal(for item: SoftwareUpdateItem) {
        let cmd = SoftwareUpdateExecutor.commandString(for: item)
        SoftwareUpdateExecutor.runInTerminal(command: cmd)
        showToast(Toast(style: .info, title: "Launched command in Terminal", detail: cmd))
    }

    func copyCommand(for item: SoftwareUpdateItem) {
        let cmd = SoftwareUpdateExecutor.commandString(for: item)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
        showToast(Toast(style: .info, title: "Copied update command"))
    }

    private func performUpdateAll() async {
        guard !isApplyingUpdates else { return }
        let itemsToUpdate = updateItems.filter {
            selectedUpdateIDs.contains($0.id) &&
            !ignoredUpdateIDs.contains($0.id) &&
            !updatedItemIDs.contains($0.id)
        }
        guard !itemsToUpdate.isEmpty else { return }

        isApplyingUpdates = true
        showUpdateLogs = true
        appendUpdateLog("═══════════════════════════════════════════════════════")
        appendUpdateLog("🚀 Starting batch update for \(itemsToUpdate.count) items...")
        appendUpdateLog("═══════════════════════════════════════════════════════")

        for (idx, item) in itemsToUpdate.enumerated() {
            updatingItemIDs.insert(item.id)
            updateProgress = (idx + 1, itemsToUpdate.count, item.displayName)

            let result = await SoftwareUpdateExecutor.upgrade(item) { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.appendUpdateLog(line)
                }
            }

            updatingItemIDs.remove(item.id)
            if result.success {
                updatedItemIDs.insert(item.id)
                failedItemErrors.removeValue(forKey: item.id)
            } else {
                failedItemErrors[item.id] = result.message
            }
        }

        updateProgress = nil
        isApplyingUpdates = false
        showToast(Toast(
            style: .success,
            title: "Updates completed",
            detail: "\(updatedItemIDs.count) items upgraded successfully."
        ))
    }

    private func performUpdateItem(_ item: SoftwareUpdateItem) async {
        guard !isApplyingUpdates, !updatingItemIDs.contains(item.id) else { return }
        updatingItemIDs.insert(item.id)
        showUpdateLogs = true

        let result = await SoftwareUpdateExecutor.upgrade(item) { [weak self] line in
            Task { @MainActor [weak self] in
                self?.appendUpdateLog(line)
            }
        }

        updatingItemIDs.remove(item.id)
        if result.success {
            updatedItemIDs.insert(item.id)
            failedItemErrors.removeValue(forKey: item.id)
            showToast(Toast(style: .success, title: "\(item.displayName) updated successfully"))
        } else {
            failedItemErrors[item.id] = result.message
            showToast(Toast(style: .error, title: "\(item.displayName) update failed", detail: result.message))
        }
    }

    // MARK: Cleaning Actions

    func requestCleanSelected() {
        guard selectedNonEmptyCount > 0, !isBusy else { return }
        confirmBeforeCleaning ? (pending = .cleanSelected) : perform(.cleanSelected)
    }

    func requestClean(_ target: CacheTarget) {
        guard !isBusy else { return }
        confirmBeforeCleaning ? (pending = .cleanTarget(target)) : perform(.cleanTarget(target))
    }

    func requestEmptyTrash() {
        guard !isBusy else { return }
        // Emptying the Trash is irreversible, so it is always confirmed.
        pending = .emptyTrash
    }

    func requestClearHistory() { pending = .clearHistory }

    func perform(_ action: PendingAction) {
        pending = nil
        switch action {
        case .cleanSelected:
            let targets = selectedRows.filter { ($0.size ?? 0) > 0 }.map(\.target)
            Task { await clean(targets) }
        case .cleanTarget(let target):
            Task { await clean([target]) }
        case .emptyTrash:
            Task { await emptyTrash() }
        case .clearHistory:
            history.clear()
            persistHistory()
            showToast(.init(style: .info, title: "History cleared"))
        case .updateAll:
            Task { await performUpdateAll() }
        case .updateItem(let item):
            Task { await performUpdateItem(item) }
        case .uninstallApp(let app):
            Task { await performUninstallApp(app) }
        case .uninstallBrewPackage(let pkg, let zap):
            Task { await performUninstallBrewPackage(pkg, zap: zap) }
        }
    }

    // MARK: - App & Package Uninstaller

    func scanInstalledApps() async {
        guard !isScanningApps else { return }
        isScanningApps = true
        let apps = await AppUninstallerScanner.scanInstalledApplications(home: home)
        self.installedApps = apps
        isScanningApps = false
        if selectedApp == nil, let first = apps.first {
            await inspectApp(first)
        }
    }

    func inspectApp(_ app: InstalledApp) async {
        guard !isInspectingApp else { return }
        isInspectingApp = true
        var appWithLeftovers = app
        let leftovers = await AppUninstallerScanner.discoverLeftovers(for: app, home: home)
        appWithLeftovers.leftovers = leftovers
        self.selectedApp = appWithLeftovers
        if let idx = self.installedApps.firstIndex(where: { $0.id == app.id }) {
            self.installedApps[idx] = appWithLeftovers
        }
        isInspectingApp = false
    }

    func inspectAppURL(_ url: URL) async {
        if let basic = AppUninstallerScanner.parseBasicApp(at: url) {
            if !installedApps.contains(where: { $0.id == basic.id }) {
                installedApps.insert(basic, at: 0)
            }
            await inspectApp(basic)
        }
    }

    func toggleLeftover(id: String) {
        guard var app = selectedApp else { return }
        if let idx = app.leftovers.firstIndex(where: { $0.id == id }) {
            app.leftovers[idx].isSelected.toggle()
            self.selectedApp = app
        }
    }

    func selectAllLeftovers(_ select: Bool) {
        guard var app = selectedApp else { return }
        for i in app.leftovers.indices {
            app.leftovers[i].isSelected = select
        }
        self.selectedApp = app
    }

    func requestUninstallApp() {
        guard let app = selectedApp, app.selectedCount > 0, !isUninstalling else { return }
        if confirmBeforeCleaning {
            pending = .uninstallApp(app)
        } else {
            perform(.uninstallApp(app))
        }
    }

    func performUninstallApp(_ app: InstalledApp) async {
        guard !isUninstalling else { return }
        isUninstalling = true
        let mode: Cleaner.Mode = deletePermanently ? .delete : .trash
        let result = await AppUninstallerExecutor.uninstall(app: app, items: app.leftovers, mode: mode)
        isUninstalling = false

        if result.removedCount > 0 {
            installedApps.removeAll { $0.id == app.id }
            selectedApp = nil
            history.record(.init(bytes: result.freedBytes, items: result.removedCount, kind: .caches, targets: ["Uninstalled \(app.displayName)"]))
            persistHistory()
            refreshDisk()
            await refreshTrash()

            let msg = "Uninstalled \(app.displayName) and \(result.removedCount) item(s), freed \(ByteText.string(result.freedBytes))"
            showToast(Toast(style: .success, title: msg))
        } else if !result.failedPaths.isEmpty {
            showToast(Toast(style: .error, title: "Failed to uninstall \(app.displayName)", detail: result.failedPaths.first))
        }
    }

    func scanBrewPackages() async {
        guard !isScanningBrewPackages else { return }
        isScanningBrewPackages = true
        let list = await HomebrewPackageManager.listInstalled()
        self.installedBrewPackages = list
        isScanningBrewPackages = false
    }

    func uninstallBrewPackage(_ pkg: InstalledBrewPackage, zap: Bool) {
        if confirmBeforeCleaning {
            pending = .uninstallBrewPackage(pkg, zap: zap)
        } else {
            perform(.uninstallBrewPackage(pkg, zap: zap))
        }
    }

    func performUninstallBrewPackage(_ pkg: InstalledBrewPackage, zap: Bool) async {
        guard !isUninstalling else { return }
        isUninstalling = true
        let res = await HomebrewPackageManager.uninstall(pkg, zap: zap)
        isUninstalling = false

        if res.exitCode == 0 {
            installedBrewPackages.removeAll { $0.id == pkg.id }
            showToast(Toast(style: .success, title: "Uninstalled \(pkg.name) successfully"))
        } else {
            showToast(Toast(style: .error, title: "Failed to uninstall \(pkg.name)", detail: res.stderr))
        }
    }

    private func clean(_ targets: [CacheTarget]) async {
        guard !targets.isEmpty, cleaning == nil, !isScanning else { return }
        let mode: Cleaner.Mode = deletePermanently ? .delete : .trash
        let cleaner = Cleaner(home: home, mode: mode)
        var freed: Int64 = 0
        var removed = 0
        var problems: [String] = []
        var touched: [String] = []

        cleaning = CleaningProgress(current: targets[0].title, completed: 0, total: targets.count)
        for (index, target) in targets.enumerated() {
            cleaning = CleaningProgress(current: target.title, completed: index, total: targets.count)
            let before = row(target.id)?.size ?? 0
            let report = await Task.detached(priority: .userInitiated) { cleaner.clean(target) }.value
            removed += report.removedItems
            problems.append(contentsOf: report.failures)
            touched.append(target.title)

            if let idx = rows.firstIndex(where: { $0.id == target.id }) {
                let after = await measure(target)
                rows[idx].size = after
                if before > after { freed += (before - after) }
            }
        }
        cleaning = CleaningProgress(current: "Done", completed: targets.count, total: targets.count)

        history.record(.init(bytes: freed, items: removed, kind: .caches, targets: touched))
        persistHistory()
        refreshDisk()
        cleaning = nil
        await refreshTrash()

        if !problems.isEmpty {
            let note = "\(problems.count) item(s) could not be removed (in use or protected)."
            showToast(.init(style: .warning,
                            title: freed > 0 ? "Freed \(ByteText.string(freed))" : "Cleanup partially failed",
                            detail: note))
        } else if freed == 0 {
            showToast(.init(style: .info, title: "Selected folders are already empty"))
        } else {
            let skippedNote = mode == .trash ? "Items moved to the Trash. Empty it to reclaim disk space." : nil
            showToast(.init(style: .success,
                            title: "Freed \(ByteText.string(freed))",
                            detail: skippedNote,
                            action: mode == .trash ? .emptyTrash : nil,
                            actionTitle: mode == .trash ? "Empty Trash…" : nil))
        }
    }

    // MARK: Trash

    func refreshTrash() async {
        isCheckingTrash = true
        let home = self.home
        let status = await Task.detached(priority: .utility) { TrashInspector.inspect(home: home) }.value
        trash = status
        if status.readable { trashFinderCount = nil }
        isCheckingTrash = false
    }

    /// Without Full Disk Access the Trash folder is unreadable; Finder can still count it.
    func countTrashWithFinder() async {
        isCheckingTrash = true
        let result = await FinderBridge.countTrashItems()
        isCheckingTrash = false
        switch result {
        case .success(let count):
            trashFinderCount = count
        case .failure(let error):
            showFinderError(error)
        }
    }

    private func emptyTrash() async {
        guard !isEmptyingTrash else { return }
        isEmptyingTrash = true
        defer { isEmptyingTrash = false }

        let before = trash?.readable == true ? trash : nil
        let result = await FinderBridge.emptyTrash()
        var bytes = before?.bytes ?? 0
        var items = before?.itemCount ?? trashFinderCount ?? 0

        switch result {
        case .success:
            break
        case .failure(let error):
            // Fall back to removing ~/.Trash contents directly when Finder automation
            // is refused but the app can read the folder.
            if error == .notAuthorized, trash?.readable == true {
                let home = self.home
                let report = await Task.detached(priority: .userInitiated) { TrashInspector.emptyDirectly(home: home) }.value
                items = report.removedItems
                if !report.failures.isEmpty {
                    await refreshTrash()
                    refreshDisk()
                    showToast(.init(style: .warning, title: "Some items stayed in the Trash",
                                    detail: "\(report.failures.count) item(s) are locked or in use."))
                    return
                }
            } else {
                showFinderError(error)
                return
            }
        }

        await refreshTrash()
        refreshDisk()
        if let after = trash, after.readable, let before { bytes = max(0, before.bytes - after.bytes) }
        trashFinderCount = nil
        history.record(.init(bytes: bytes, items: items, kind: .trash, targets: ["Trash"]))
        persistHistory()
        showToast(.init(style: .success,
                        title: bytes > 0 ? "Emptied the Trash, freed \(ByteText.string(bytes))" : "Emptied the Trash",
                        detail: nil))
    }

    private func showFinderError(_ error: FinderBridge.Failure) {
        switch error {
        case .notAuthorized:
            var toast = Toast(style: .error, title: "\(Brand.appName) may not control Finder",
                              detail: "Allow it in System Settings › Privacy & Security › Automation, or grant Full Disk Access.")
            toast.action = .openAutomation
            toast.actionTitle = "Open Settings"
            showToast(toast)
        case .other(let message):
            showToast(.init(style: .error, title: "Finder reported an error", detail: message))
        }
    }

    // MARK: History

    private func persistHistory() {
        defaults.set(history.encoded(), forKey: Keys.history)
    }

    // MARK: Toasts

    func showToast(_ toast: Toast) {
        toastTask?.cancel()
        self.toast = toast
        let seconds: UInt64 = toast.action == nil ? 5 : 10
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.dismissToast(toast.id)
        }
    }

    func dismissToast(_ id: UUID? = nil) {
        if id == nil || toast?.id == id { toast = nil }
    }

    func runToastAction(_ action: Toast.Action) {
        dismissToast()
        switch action {
        case .emptyTrash: requestEmptyTrash()
        case .openFullDiskAccess: SystemSettings.open(.fullDiskAccess)
        case .openAutomation: SystemSettings.open(.automation)
        case .showTrash: selection = .trash
        }
    }

    // MARK: Finder and files

    func reveal(_ target: CacheTarget) {
        let urls = target.resolvedURLs(home: home).filter { FileManager.default.fileExists(atPath: $0.path) }
        if urls.isEmpty {
            showToast(.init(style: .info, title: "\(target.title) has no cache folder on this Mac"))
        } else {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
    }

    func copyPaths(_ target: CacheTarget) {
        let text = target.resolvedURLs(home: home).map(\.path).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast(.init(style: .info, title: "Copied \(target.paths.count) path(s)"))
    }

    func openTrashInFinder() {
        NSWorkspace.shared.open(TrashInspector.trashURL(home: home))
    }

    func openCustomTargetsFile() {
        let url = Catalog.userFileURL(home: home)
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            do {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let sample = """
                [
                  {
                    "id": "example.app",
                    "title": "Example App",
                    "summary": "Replace with a real cache folder, then choose Reload Definitions.",
                    "kind": "custom",
                    "paths": ["~/Library/Caches/com.example.app"]
                  }
                ]
                """
                try sample.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                showToast(.init(style: .error, title: "Could not create the definitions file", detail: error.localizedDescription))
                return
            }
        }
        NSWorkspace.shared.open(url)
    }
}
