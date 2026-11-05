import Foundation
import AppKit

/// Category classification for files left behind by an application.
public enum LeftoverCategory: String, CaseIterable, Codable, Sendable {
    case bundle = "bundle"
    case applicationSupport = "applicationSupport"
    case caches = "caches"
    case preferences = "preferences"
    case containers = "containers"
    case savedState = "savedState"
    case httpStoragesAndWebKit = "webKit"
    case logs = "logs"
    case launchAgents = "launchAgents"
    case other = "other"

    public var title: String {
        switch self {
        case .bundle: return "Application Bundle"
        case .applicationSupport: return "Application Support"
        case .caches: return "Caches"
        case .preferences: return "Preferences"
        case .containers: return "Containers & Sandboxes"
        case .savedState: return "Saved State"
        case .httpStoragesAndWebKit: return "WebKit & Network Data"
        case .logs: return "Logs & Crash Reports"
        case .launchAgents: return "Launch Agents"
        case .other: return "Other Data"
        }
    }

    public var systemImage: String {
        switch self {
        case .bundle: return "app.fill"
        case .applicationSupport: return "folder.fill"
        case .caches: return "sparkles"
        case .preferences: return "gearshape.fill"
        case .containers: return "shippingbox.fill"
        case .savedState: return "clock.arrow.circlepath"
        case .httpStoragesAndWebKit: return "network"
        case .logs: return "doc.text.fill"
        case .launchAgents: return "bolt.fill"
        case .other: return "ellipsis.circle"
        }
    }
}

/// A specific file or directory left behind by an application.
public struct AppLeftoverItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let path: String
    public let category: LeftoverCategory
    public let bytes: Int64
    public var isSelected: Bool

    public init(
        id: String? = nil,
        name: String,
        url: URL,
        category: LeftoverCategory,
        bytes: Int64,
        isSelected: Bool = true
    ) {
        self.id = id ?? url.path
        self.name = name
        self.url = url
        self.path = url.path
        self.category = category
        self.bytes = bytes
        self.isSelected = isSelected
    }
}

/// An installed application detected on macOS.
public struct InstalledApp: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let displayName: String
    public let bundleIdentifier: String?
    public let bundleURL: URL
    public let version: String
    public let isSystemApp: Bool
    public var brewCaskName: String?
    public var leftovers: [AppLeftoverItem]

    public var totalBytes: Int64 {
        leftovers.reduce(0) { $0 + $1.bytes }
    }

    public var selectedBytes: Int64 {
        leftovers.filter(\.isSelected).reduce(0) { $0 + $1.bytes }
    }

    public var selectedCount: Int {
        leftovers.filter(\.isSelected).count
    }

    public init(
        id: String,
        name: String,
        displayName: String,
        bundleIdentifier: String?,
        bundleURL: URL,
        version: String,
        isSystemApp: Bool = false,
        brewCaskName: String? = nil,
        leftovers: [AppLeftoverItem] = []
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.bundleURL = bundleURL
        self.version = version
        self.isSystemApp = isSystemApp
        self.brewCaskName = brewCaskName
        self.leftovers = leftovers
    }
}

/// A Homebrew package (cask or formula) installed on the system.
public struct InstalledBrewPackage: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let isCask: Bool
    public let summary: String?

    public init(name: String, version: String, isCask: Bool, summary: String? = nil) {
        self.id = "\(isCask ? "cask" : "formula"):\(name)"
        self.name = name
        self.version = version
        self.isCask = isCask
        self.summary = summary
    }
}
