import Foundation

/// Measures how much disk space a folder occupies.
public enum SizeScanner {
    /// Returns the allocated size in bytes of everything inside `url`.
    /// Missing folders count as zero. Symbolic links are counted as links, never followed,
    /// so a link pointing at a large folder elsewhere does not inflate the result.
    public static func allocatedSize(of url: URL, fileManager: FileManager = .default) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if isSymlink(url, fileManager: fileManager) { return 0 }
        guard isDir.boolValue else { return fileSize(url) }

        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let item as URL in enumerator {
            if FolderAppearancePolicy.isFolderColorOrIconFile(item) { continue }
            guard let values = try? item.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true { continue }
            guard values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }

    public static func allocatedSize(of target: CacheTarget, home: URL, fileManager: FileManager = .default) -> Int64 {
        target.resolvedURLs(home: home)
            .filter { PathPolicy.isAllowed($0, home: home) }
            .reduce(0) { $0 + allocatedSize(of: $1, fileManager: fileManager) }
    }

    static func isSymlink(_ url: URL, fileManager: FileManager) -> Bool {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path) else { return false }
        return (attrs[.type] as? FileAttributeType) == .typeSymbolicLink
    }

    private static func fileSize(_ url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey])
        return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0)
    }
}

public enum ByteText {
    public static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }
}
