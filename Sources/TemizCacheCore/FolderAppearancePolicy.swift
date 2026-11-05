import Foundation
import AppKit

/// Guarantees that folder colors, custom icons, Finder labels, and tags are never removed or cleaned.
public enum FolderAppearancePolicy {

    /// Names of files responsible for folder icons and Finder appearance.
    public static let appearanceFileNames: Set<String> = [
        "Icon\r",
        "Icon\u{0D}",
        ".DS_Store",
        ".localized"
    ]

    /// Checks if a file is an appearance/icon resource that must be preserved.
    public static func isFolderColorOrIconFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if appearanceFileNames.contains(name) || name.hasPrefix("Icon\r") {
            return true
        }
        return false
    }

    /// Checks if a directory has a custom icon, custom color, label, or Finder tag.
    public static func hasCustomColorOrIcon(_ url: URL, fileManager: FileManager = .default) -> Bool {
        let path = url.path

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return isFolderColorOrIconFile(url)
        }

        // 1. Check for custom icon file "Icon\r" inside the directory
        let iconURL = url.appendingPathComponent("Icon\r")
        if fileManager.fileExists(atPath: iconURL.path) {
            return true
        }

        // 2. Check for Finder tags / label color via URL resource values
        if let values = try? url.resourceValues(forKeys: [.tagNamesKey, .customIconKey, .labelNumberKey]) {
            if values.customIcon != nil { return true }
            if let tags = values.tagNames, !tags.isEmpty { return true }
            if let label = values.labelNumber, label > 0 { return true }
        }

        // 3. Check extended attributes (com.apple.FinderInfo & com.apple.metadata:_kMDItemUserTags)
        let fiSize = getxattr(path, "com.apple.FinderInfo", nil, 0, 0, 0)
        if fiSize >= 10 {
            var buf = [UInt8](repeating: 0, count: max(32, fiSize))
            if getxattr(path, "com.apple.FinderInfo", &buf, buf.count, 0, 0) >= 10 {
                // Finder flags: bit 0x0400 is kHasCustomIcon, bits 0x000E is color label
                let flags = (UInt16(buf[8]) << 8) | UInt16(buf[9])
                let hasCustomIcon = (flags & 0x0400) != 0
                let hasColorLabel = (flags & 0x000E) != 0
                if hasCustomIcon || hasColorLabel {
                    return true
                }
            }
        }

        let utSize = getxattr(path, "com.apple.metadata:_kMDItemUserTags", nil, 0, 0, 0)
        if utSize > 0 {
            return true
        }

        return false
    }

    /// Backs up folder icon and appearance attributes, runs the block, and restores them if needed.
    public static func preserveAppearance<T>(of folder: URL, operation: () throws -> T) rethrows -> T {
        let path = folder.path
        let fm = FileManager.default

        let iconURL = folder.appendingPathComponent("Icon\r")
        let iconData = try? Data(contentsOf: iconURL)

        var finderInfoData: Data? = nil
        let fiSize = getxattr(path, "com.apple.FinderInfo", nil, 0, 0, 0)
        if fiSize > 0 {
            var buf = [UInt8](repeating: 0, count: fiSize)
            if getxattr(path, "com.apple.FinderInfo", &buf, buf.count, 0, 0) > 0 {
                finderInfoData = Data(buf)
            }
        }

        var userTagsData: Data? = nil
        let utSize = getxattr(path, "com.apple.metadata:_kMDItemUserTags", nil, 0, 0, 0)
        if utSize > 0 {
            var buf = [UInt8](repeating: 0, count: utSize)
            if getxattr(path, "com.apple.metadata:_kMDItemUserTags", &buf, buf.count, 0, 0) > 0 {
                userTagsData = Data(buf)
            }
        }

        let result = try operation()

        // Restore Icon\r if it existed and was removed
        if let iconData, !fm.fileExists(atPath: iconURL.path) {
            try? iconData.write(to: iconURL)
            // Make Icon\r hidden
            var hideAttrs = [UInt8](repeating: 0, count: 32)
            hideAttrs[8] = 0x40 // invisible flag
            _ = setxattr(iconURL.path, "com.apple.FinderInfo", hideAttrs, 32, 0, 0)
        }

        // Restore FinderInfo
        if let finderInfoData {
            _ = finderInfoData.withUnsafeBytes { ptr in
                setxattr(path, "com.apple.FinderInfo", ptr.baseAddress, finderInfoData.count, 0, 0)
            }
        }

        // Restore UserTags
        if let userTagsData {
            _ = userTagsData.withUnsafeBytes { ptr in
                setxattr(path, "com.apple.metadata:_kMDItemUserTags", ptr.baseAddress, userTagsData.count, 0, 0)
            }
        }

        return result
    }
}
