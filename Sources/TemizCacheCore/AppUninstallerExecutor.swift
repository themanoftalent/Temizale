import Foundation
import AppKit

/// Executes complete uninstallation of an application and its leftovers.
public enum AppUninstallerExecutor {

    public struct Result: Sendable {
        public let freedBytes: Int64
        public let removedCount: Int
        public let failedPaths: [String]
        public let homebrewUninstalled: Bool
    }

    /// Uninstalls the selected items for an app.
    public static func uninstall(
        app: InstalledApp,
        items: [AppLeftoverItem],
        mode: Cleaner.Mode,
        fileManager: FileManager = .default
    ) async -> Result {
        var freed: Int64 = 0
        var removed = 0
        var failures: [String] = []
        var removedBundle = false

        let selected = items.filter(\.isSelected)

        for item in selected {
            let url = item.url
            guard fileManager.fileExists(atPath: url.path) else { continue }

            do {
                if mode == .trash {
                    try fileManager.trashItem(at: url, resultingItemURL: nil)
                } else {
                    try fileManager.removeItem(at: url)
                }
                freed += item.bytes
                removed += 1

                if item.category == .bundle {
                    removedBundle = true
                }
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // If app bundle was removed and has an associated Homebrew cask, also update Homebrew
        var brewRemoved = false
        if removedBundle, let cask = app.brewCaskName, let brew = CommandRunner.which("brew") {
            let res = await CommandRunner.run(brew, arguments: ["uninstall", "--cask", cask])
            brewRemoved = res.exitCode == 0
        }

        return Result(
            freedBytes: freed,
            removedCount: removed,
            failedPaths: failures,
            homebrewUninstalled: brewRemoved
        )
    }
}
