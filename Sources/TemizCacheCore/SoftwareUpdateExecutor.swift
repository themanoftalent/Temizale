import Foundation
import AppKit

/// Executes updates for applications and packages, streaming output logs.
public enum SoftwareUpdateExecutor {

    public struct UpdateResult: Sendable {
        public let success: Bool
        public let message: String
    }

    /// Upgrades a single update item.
    public static func upgrade(
        _ item: SoftwareUpdateItem,
        onOutput: @escaping @Sendable (String) -> Void
    ) async -> UpdateResult {
        onOutput("🚀 Starting update for \(item.displayName)...")

        switch item.source {
        case .brewCask:
            guard let brew = CommandRunner.which("brew") else {
                let msg = "Homebrew not found in PATH"
                onOutput("❌ \(msg)")
                return UpdateResult(success: false, message: msg)
            }
            onOutput("$ brew upgrade --cask \(item.rawIdentifier)")
            let status = await CommandRunner.stream(brew, arguments: ["upgrade", "--cask", item.rawIdentifier], onOutput: onOutput)
            let success = status == 0
            onOutput(success ? "✅ Successfully updated \(item.displayName)" : "❌ Update failed with exit code \(status)")
            return UpdateResult(success: success, message: success ? "Updated" : "Failed (exit code \(status))")

        case .brewFormula:
            guard let brew = CommandRunner.which("brew") else {
                let msg = "Homebrew not found in PATH"
                onOutput("❌ \(msg)")
                return UpdateResult(success: false, message: msg)
            }
            onOutput("$ brew upgrade \(item.rawIdentifier)")
            let status = await CommandRunner.stream(brew, arguments: ["upgrade", item.rawIdentifier], onOutput: onOutput)
            let success = status == 0
            onOutput(success ? "✅ Successfully updated \(item.displayName)" : "❌ Update failed with exit code \(status)")
            return UpdateResult(success: success, message: success ? "Updated" : "Failed (exit code \(status))")

        case .mas:
            guard let mas = CommandRunner.which("mas") else {
                let msg = "mas CLI tool not found in PATH"
                onOutput("❌ \(msg)")
                return UpdateResult(success: false, message: msg)
            }
            onOutput("$ mas upgrade \(item.rawIdentifier)")
            let status = await CommandRunner.stream(mas, arguments: ["upgrade", item.rawIdentifier], onOutput: onOutput)
            let success = status == 0
            onOutput(success ? "✅ Successfully updated \(item.displayName)" : "❌ Update failed with exit code \(status)")
            return UpdateResult(success: success, message: success ? "Updated" : "Failed (exit code \(status))")

        case .system:
            guard let su = CommandRunner.which("softwareupdate") else {
                let msg = "softwareupdate utility not found"
                onOutput("❌ \(msg)")
                return UpdateResult(success: false, message: msg)
            }
            onOutput("$ softwareupdate --install \(item.rawIdentifier)")
            let status = await CommandRunner.stream(su, arguments: ["--install", item.rawIdentifier], onOutput: onOutput)
            let success = status == 0
            onOutput(success ? "✅ Successfully installed system update \(item.displayName)" : "❌ Update failed with exit code \(status)")
            return UpdateResult(success: success, message: success ? "Updated" : "Failed (exit code \(status))")

        case .npm:
            guard let npm = CommandRunner.which("npm") else {
                let msg = "npm not found in PATH"
                onOutput("❌ \(msg)")
                return UpdateResult(success: false, message: msg)
            }
            onOutput("$ npm install -g \(item.rawIdentifier)@latest")
            let status = await CommandRunner.stream(npm, arguments: ["install", "-g", "\(item.rawIdentifier)@latest"], onOutput: onOutput)
            let success = status == 0
            onOutput(success ? "✅ Successfully updated \(item.displayName)" : "❌ Update failed with exit code \(status)")
            return UpdateResult(success: success, message: success ? "Updated" : "Failed (exit code \(status))")

        case .pip:
            guard let pip = CommandRunner.which("pip3") ?? CommandRunner.which("pip") else {
                let msg = "pip not found in PATH"
                onOutput("❌ \(msg)")
                return UpdateResult(success: false, message: msg)
            }
            onOutput("$ pip3 install --upgrade \(item.rawIdentifier)")
            let status = await CommandRunner.stream(pip, arguments: ["install", "--upgrade", item.rawIdentifier], onOutput: onOutput)
            let success = status == 0
            onOutput(success ? "✅ Successfully updated \(item.displayName)" : "❌ Update failed with exit code \(status)")
            return UpdateResult(success: success, message: success ? "Updated" : "Failed (exit code \(status))")

        case .sparkle:
            if let url = item.releaseNotesURL {
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(url)
                }
                onOutput("ℹ️ Opened update link: \(url.absoluteString)")
                return UpdateResult(success: true, message: "Opened update page")
            } else if let path = item.appBundlePath {
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                }
                onOutput("ℹ️ Launched \(item.displayName) to trigger built-in update check")
                return UpdateResult(success: true, message: "Launched app")
            }
            return UpdateResult(success: false, message: "No update URL available")
        }
    }

    /// Upgrades all provided items sequentially or in batches.
    public static func upgradeAll(
        _ items: [SoftwareUpdateItem],
        onProgress: @escaping @Sendable (Int, Int, String) -> Void,
        onOutput: @escaping @Sendable (String) -> Void
    ) async -> [String: UpdateResult] {
        var results: [String: UpdateResult] = [:]
        let total = items.count
        onOutput("═══════════════════════════════════════════════════════")
        onOutput("🚀 Beginning batch update for \(total) items")
        onOutput("═══════════════════════════════════════════════════════")

        for (index, item) in items.enumerated() {
            onProgress(index + 1, total, item.displayName)
            onOutput("\n[\(index + 1)/\(total)] Processing: \(item.displayName) (\(item.source.shortTitle))")
            let res = await upgrade(item, onOutput: onOutput)
            results[item.id] = res
        }

        let successful = results.values.filter(\.success).count
        onOutput("\n═══════════════════════════════════════════════════════")
        onOutput("🏁 Completed: \(successful)/\(total) updates succeeded")
        onOutput("═══════════════════════════════════════════════════════")
        return results
    }
}
