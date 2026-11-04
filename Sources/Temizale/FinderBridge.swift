import Foundation
import AppKit

/// Talks to Finder through Apple Events. macOS asks the user once for permission
/// ("AleTemizCache wants to control Finder"); the reason text comes from
/// NSAppleEventsUsageDescription in Info.plist.
enum FinderBridge {
    enum Failure: Error, Equatable {
        case notAuthorized
        case other(String)
    }

    static func emptyTrash() async -> Result<Void, Failure> {
        await run("tell application \"Finder\" to empty trash").map { _ in () }
    }

    static func countTrashItems() async -> Result<Int, Failure> {
        await run("tell application \"Finder\" to count items of trash").flatMap { output in
            if let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return .success(count)
            }
            return .failure(.other("Unexpected reply from Finder: \(output)"))
        }
    }

    /// Runs AppleScript off the main thread so a long empty does not freeze the UI.
    private static func run(_ source: String) async -> Result<String, Failure> {
        await Task.detached(priority: .userInitiated) { () -> Result<String, Failure> in
            var errorInfo: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                return .failure(.other("Could not compile AppleScript."))
            }
            let descriptor = script.executeAndReturnError(&errorInfo)
            if let errorInfo {
                let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
                // -1743: not authorized to send Apple Events. -1744: user consent required.
                if code == -1743 || code == -1744 { return .failure(.notAuthorized) }
                let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Error \(code)"
                return .failure(.other(message))
            }
            return .success(descriptor.stringValue ?? "")
        }.value
    }
}

enum SystemSettings {
    enum Pane {
        case fullDiskAccess, automation

        var url: URL {
            switch self {
            case .fullDiskAccess:
                return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
            case .automation:
                return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
            }
        }
    }

    static func open(_ pane: Pane) {
        NSWorkspace.shared.open(pane.url)
    }
}
