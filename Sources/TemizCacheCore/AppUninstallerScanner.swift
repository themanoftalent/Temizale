import Foundation
import AppKit

/// Scans installed applications and discovers all associated leftover files.
public enum AppUninstallerScanner {

    /// Scans installed user-accessible applications.
    public static func scanInstalledApplications(home: URL = FileManager.default.homeDirectoryForCurrentUser) async -> [InstalledApp] {
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications")
        ]

        var apps: [InstalledApp] = []
        let fm = FileManager.default

        // Query installed Homebrew casks to link them
        let brewCasks: Set<String>
        if let brew = CommandRunner.which("brew") {
            let res = await CommandRunner.run(brew, arguments: ["list", "--cask", "-1"])
            let lines = res.stdout.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            brewCasks = Set(lines.filter { !$0.isEmpty })
        } else {
            brewCasks = []
        }

        for dir in appDirs {
            guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
                continue
            }

            for url in contents where url.pathExtension == "app" {
                // Skip Temizale itself
                if url.lastPathComponent == "Temizale.app" || url.lastPathComponent == "AleTemizCache.app" {
                    continue
                }

                if let app = parseBasicApp(at: url, brewCasks: brewCasks) {
                    apps.append(app)
                }
            }
        }

        return apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Parses basic metadata for an app bundle without scanning its full leftovers yet.
    public static func parseBasicApp(at url: URL, brewCasks: Set<String> = []) -> InstalledApp? {
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else {
            return nil
        }

        let bundleID = plist["CFBundleIdentifier"] as? String
        let name = plist["CFBundleDisplayName"] as? String
            ?? plist["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        let version = plist["CFBundleShortVersionString"] as? String
            ?? plist["CFBundleVersion"] as? String
            ?? "Unknown"

        let isSystem = url.path.hasPrefix("/System/") || bundleID?.hasPrefix("com.apple.") == true

        // Match with brew cask if applicable
        let appBase = url.deletingPathExtension().lastPathComponent.lowercased().replacingOccurrences(of: " ", with: "-")
        let matchedCask = brewCasks.first { $0.lowercased() == appBase || (bundleID != nil && $0.lowercased().contains(bundleID!.lowercased())) }

        return InstalledApp(
            id: url.path,
            name: url.deletingPathExtension().lastPathComponent,
            displayName: name,
            bundleIdentifier: bundleID,
            bundleURL: url,
            version: version,
            isSystemApp: isSystem,
            brewCaskName: matchedCask,
            leftovers: []
        )
    }

    /// Performs deep leftover discovery for a specific app.
    public static func discoverLeftovers(for app: InstalledApp, home: URL = FileManager.default.homeDirectoryForCurrentUser) async -> [AppLeftoverItem] {
        let fm = FileManager.default
        var items: [AppLeftoverItem] = []

        // 1. Primary App Bundle
        if fm.fileExists(atPath: app.bundleURL.path) {
            let bundleSize = SizeScanner.allocatedSize(of: app.bundleURL)
            items.append(AppLeftoverItem(
                id: "bundle:\(app.bundleURL.path)",
                name: app.bundleURL.lastPathComponent,
                url: app.bundleURL,
                category: .bundle,
                bytes: bundleSize,
                isSelected: true
            ))
        }

        let bundleID = app.bundleIdentifier?.trimmingCharacters(in: .whitespaces)
        let appName = app.name.trimmingCharacters(in: .whitespaces)
        let cleanName = app.displayName.trimmingCharacters(in: .whitespaces)

        // Safety tokens: only search if we have a valid identifier or app name with length >= 3
        var searchTokens: Set<String> = []
        if let bundleID, bundleID.count >= 4, !bundleID.hasPrefix("com.apple.") {
            searchTokens.insert(bundleID.lowercased())
        }
        if appName.count >= 3 {
            searchTokens.insert(appName.lowercased())
        }
        if cleanName.count >= 3 {
            searchTokens.insert(cleanName.lowercased())
        }

        guard !searchTokens.isEmpty else { return items }

        // Candidate directories to search
        struct CandidateSearch {
            let directory: URL
            let category: LeftoverCategory
            let deepMatch: Bool
        }

        let searches: [CandidateSearch] = [
            CandidateSearch(directory: home.appendingPathComponent("Library/Application Support"), category: .applicationSupport, deepMatch: false),
            CandidateSearch(directory: home.appendingPathComponent("Library/Caches"), category: .caches, deepMatch: false),
            CandidateSearch(directory: home.appendingPathComponent("Library/Preferences"), category: .preferences, deepMatch: false),
            CandidateSearch(directory: home.appendingPathComponent("Library/Containers"), category: .containers, deepMatch: false),
            CandidateSearch(directory: home.appendingPathComponent("Library/Group Containers"), category: .containers, deepMatch: false),
            CandidateSearch(directory: home.appendingPathComponent("Library/Saved Application State"), category: .savedState, deepMatch: false),
            CandidateSearch(directory: home.appendingPathComponent("Library/HTTPStorages"), category: .httpStoragesAndWebKit, deepMatch: false),
            CandidateSearch(directory: home.appendingPathComponent("Library/WebKit"), category: .httpStoragesAndWebKit, deepMatch: false),
            CandidateSearch(directory: home.appendingPathComponent("Library/Logs"), category: .logs, deepMatch: false),
            CandidateSearch(directory: home.appendingPathComponent("Library/Logs/DiagnosticReports"), category: .logs, deepMatch: false),
            CandidateSearch(directory: home.appendingPathComponent("Library/LaunchAgents"), category: .launchAgents, deepMatch: false),
            CandidateSearch(directory: URL(fileURLWithPath: "/Library/Application Support"), category: .applicationSupport, deepMatch: false),
            CandidateSearch(directory: URL(fileURLWithPath: "/Library/Caches"), category: .caches, deepMatch: false)
        ]

        var foundURLs = Set<URL>()
        foundURLs.insert(app.bundleURL)

        for candidate in searches {
            guard let entries = try? fm.contentsOfDirectory(at: candidate.directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }

            for entry in entries {
                let entryName = entry.lastPathComponent.lowercased()

                // Check if entry matches bundleID or app name
                let matches: Bool
                if let bundleID, entryName == bundleID.lowercased() || entryName == "\(bundleID.lowercased()).plist" || entryName == "\(bundleID.lowercased()).savedstate" {
                    matches = true
                } else if entryName == appName.lowercased() || entryName == "\(appName.lowercased()).plist" {
                    matches = true
                } else if searchTokens.contains(where: { token in
                    if candidate.category == .preferences {
                        return entryName == "\(token).plist"
                    } else if candidate.category == .savedState {
                        return entryName == "\(token).savedstate"
                    } else {
                        return entryName == token
                    }
                }) {
                    matches = true
                } else {
                    matches = false
                }

                if matches && !foundURLs.contains(entry) {
                    // Critical safety check: never delete system roots
                    if isSafeToDelete(entry, home: home) {
                        foundURLs.insert(entry)
                        let size = SizeScanner.allocatedSize(of: entry)
                        items.append(AppLeftoverItem(
                            id: "\(candidate.category.rawValue):\(entry.path)",
                            name: entry.lastPathComponent,
                            url: entry,
                            category: candidate.category,
                            bytes: size,
                            isSelected: true
                        ))
                    }
                }
            }
        }

        return items
    }

    /// Verifies that a path is safe to be classified as a leftover and removed.
    private static func isSafeToDelete(_ url: URL, home: URL) -> Bool {
        let path = url.path
        let homePath = home.path

        // Disallow deleting folder color / icon files directly
        if FolderAppearancePolicy.isFolderColorOrIconFile(url) {
            return false
        }

        // Disallow deleting folders that have custom colors or icons (unless it is an .app bundle)
        if url.pathExtension != "app" && FolderAppearancePolicy.hasCustomColorOrIcon(url, fileManager: FileManager.default) {
            return false
        }

        // Disallow deleting top-level directories
        let forbidden = [
            "/",
            "/Applications",
            "/Library",
            "/System",
            "/Users",
            homePath,
            "\(homePath)/Library",
            "\(homePath)/Library/Application Support",
            "\(homePath)/Library/Caches",
            "\(homePath)/Library/Preferences",
            "\(homePath)/Library/Containers",
            "\(homePath)/Library/Logs"
        ]
        if forbidden.contains(path) { return false }

        // Must be inside Library or Applications
        let isInsideUserLibrary = path.hasPrefix("\(homePath)/Library/")
        let isInsideSystemLibrary = path.hasPrefix("/Library/Application Support/") || path.hasPrefix("/Library/Caches/")
        let isInsideApplications = path.hasPrefix("/Applications/") || path.hasPrefix("\(homePath)/Applications/")

        guard isInsideUserLibrary || isInsideSystemLibrary || isInsideApplications else {
            return false
        }

        // Avoid removing Apple-critical shared folders
        if path.hasSuffix("/com.apple.finder") || path.hasSuffix("/com.apple.dock") {
            return false
        }

        return true
    }
}
