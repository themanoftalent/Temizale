import Foundation

/// Reads and empties the user's Trash folder (`~/.Trash`).
///
/// On macOS 10.15 and later the Trash folder is protected by privacy controls.
/// Reading it needs Full Disk Access. When access is missing, `inspect` reports
/// `readable == false` instead of guessing a size.
public enum TrashInspector {
    public struct Status: Equatable, Sendable {
        public let bytes: Int64
        public let itemCount: Int
        public let readable: Bool

        public init(bytes: Int64, itemCount: Int, readable: Bool) {
            self.bytes = bytes
            self.itemCount = itemCount
            self.readable = readable
        }

        public static let unreadable = Status(bytes: 0, itemCount: 0, readable: false)
        public var isEmpty: Bool { readable && itemCount == 0 }
    }

    public static func trashURL(home: URL) -> URL {
        home.appendingPathComponent(".Trash", isDirectory: true)
    }

    public static func inspect(home: URL, fileManager: FileManager = .default) -> Status {
        let url = trashURL(home: home)
        guard fileManager.fileExists(atPath: url.path) else {
            return Status(bytes: 0, itemCount: 0, readable: true)
        }
        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        } catch {
            return .unreadable
        }
        // Appearance and icon files (e.g. .DS_Store, Icon\r) are preserved and not counted as user items.
        let items = children.filter { !FolderAppearancePolicy.isFolderColorOrIconFile($0) }
        let bytes = items.reduce(Int64(0)) { $0 + SizeScanner.allocatedSize(of: $1, fileManager: fileManager) }
        return Status(bytes: bytes, itemCount: items.count, readable: true)
    }

    /// Permanently removes everything inside `~/.Trash` without following symlinks.
    /// The app prefers asking Finder to empty the Trash because Finder also handles
    /// Trash folders on external volumes and locked items. This direct path is the
    /// fallback when Finder automation is denied but file access works.
    public static func emptyDirectly(home: URL, fileManager: FileManager = .default) -> Cleaner.Report {
        var report = Cleaner.Report()
        let url = trashURL(home: home)
        guard fileManager.fileExists(atPath: url.path) else { return report }
        if SizeScanner.isSymlink(url, fileManager: fileManager) {
            report.refused.append("Skipped symbolic link: \(url.path)")
            return report
        }
        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        } catch {
            report.failures.append("\(url.path): \(error.localizedDescription)")
            return report
        }
        FolderAppearancePolicy.preserveAppearance(of: url) {
            for child in children {
                if FolderAppearancePolicy.isFolderColorOrIconFile(child) {
                    continue
                }
                do {
                    try fileManager.removeItem(at: child)
                    report.removedItems += 1
                } catch {
                    report.failures.append("\(child.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        return report
    }
}
