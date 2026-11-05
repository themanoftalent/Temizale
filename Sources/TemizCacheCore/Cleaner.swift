import Foundation

/// Empties cache folders. The folder itself stays in place so that apps
/// which expect it to exist keep working; only its contents go.
public struct Cleaner: Sendable {
    public enum Mode: String, Sendable, CaseIterable {
        /// Moves items to the Trash. Recoverable until the Trash is emptied.
        case trash
        /// Deletes items immediately.
        case delete
    }

    public struct Report: Sendable {
        public var removedItems: Int = 0
        public var failures: [String] = []
        public var refused: [String] = []
    }

    public let home: URL
    public let mode: Mode

    public init(home: URL, mode: Mode) {
        self.home = home
        self.mode = mode
    }

    public func clean(_ target: CacheTarget, fileManager: FileManager = .default) -> Report {
        var report = Report()
        for folder in target.resolvedURLs(home: home) {
            do {
                try PathPolicy.validate(folder, home: home)
            } catch {
                report.refused.append("\(error)")
                continue
            }
            // Never follow a symlinked cache folder to wherever it points.
            if SizeScanner.isSymlink(folder, fileManager: fileManager) {
                report.refused.append("Skipped symbolic link: \(folder.path)")
                continue
            }
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else { continue }

            FolderAppearancePolicy.preserveAppearance(of: folder) {
                let children: [URL]
                do {
                    children = try fileManager.contentsOfDirectory(
                        at: folder,
                        includingPropertiesForKeys: nil,
                        options: []
                    )
                } catch {
                    report.failures.append("\(folder.path): \(error.localizedDescription)")
                    return
                }

                for child in children {
                    // Never remove folder color, tag, or custom icon files (e.g. Icon\r, .DS_Store)
                    if FolderAppearancePolicy.isFolderColorOrIconFile(child) {
                        continue
                    }
                    // Never remove subfolders that have custom color or custom icons
                    if FolderAppearancePolicy.hasCustomColorOrIcon(child, fileManager: fileManager) {
                        continue
                    }

                    do {
                        try remove(child, fileManager: fileManager)
                        report.removedItems += 1
                    } catch {
                        report.failures.append("\(child.path): \(error.localizedDescription)")
                    }
                }
            }
        }
        return report
    }

    private func remove(_ url: URL, fileManager: FileManager) throws {
        switch mode {
        case .delete:
            try fileManager.removeItem(at: url)
        case .trash:
            #if os(macOS)
            try fileManager.trashItem(at: url, resultingItemURL: nil)
            #else
            try fileManager.removeItem(at: url)
            #endif
        }
    }
}
