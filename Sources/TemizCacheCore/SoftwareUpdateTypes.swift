import Foundation

/// The source providing the update.
public enum UpdateSource: String, CaseIterable, Codable, Sendable {
    case brewCask = "cask"
    case brewFormula = "formula"
    case mas = "mas"
    case system = "system"
    case sparkle = "sparkle"
    case npm = "npm"
    case pip = "pip"

    public var title: String {
        switch self {
        case .brewCask: return "App (Homebrew)"
        case .brewFormula: return "Homebrew Formula"
        case .mas: return "Mac App Store"
        case .system: return "macOS System"
        case .sparkle: return "Direct Application"
        case .npm: return "npm Global"
        case .pip: return "pip Package"
        }
    }

    public var shortTitle: String {
        switch self {
        case .brewCask: return "Cask"
        case .brewFormula: return "Formula"
        case .mas: return "App Store"
        case .system: return "System"
        case .sparkle: return "Direct"
        case .npm: return "npm"
        case .pip: return "pip"
        }
    }

    public var systemImage: String {
        switch self {
        case .brewCask: return "macwindow"
        case .brewFormula: return "shippingbox"
        case .mas: return "apple.logo"
        case .system: return "gearshape.2"
        case .sparkle: return "sparkles"
        case .npm: return "shippingbox.fill"
        case .pip: return "cube.transparent"
        }
    }

    public var isApplication: Bool {
        switch self {
        case .brewCask, .mas, .sparkle: return true
        case .brewFormula, .system, .npm, .pip: return false
        }
    }
}

/// The state of an update action.
public enum UpdateStatus: Equatable, Sendable {
    case idle
    case updating
    case updated
    case failed(String)

    public var isBusy: Bool {
        if case .updating = self { return true }
        return false
    }
}

/// A single software application or package update.
public struct SoftwareUpdateItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let displayName: String
    public let installedVersion: String
    public let latestVersion: String
    public let source: UpdateSource
    public let rawIdentifier: String
    public let appBundlePath: String?
    public let releaseNotesURL: URL?

    public init(
        id: String,
        name: String,
        displayName: String? = nil,
        installedVersion: String,
        latestVersion: String,
        source: UpdateSource,
        rawIdentifier: String,
        appBundlePath: String? = nil,
        releaseNotesURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName ?? name
        self.installedVersion = installedVersion
        self.latestVersion = latestVersion
        self.source = source
        self.rawIdentifier = rawIdentifier
        self.appBundlePath = appBundlePath
        self.releaseNotesURL = releaseNotesURL
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: SoftwareUpdateItem, rhs: SoftwareUpdateItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Options to control which sources to scan.
public struct UpdateCheckOptions: Sendable {
    public var checkBrew: Bool
    public var checkMas: Bool
    public var checkSystem: Bool
    public var checkSparkle: Bool
    public var checkDevPackages: Bool

    public init(
        checkBrew: Bool = true,
        checkMas: Bool = true,
        checkSystem: Bool = true,
        checkSparkle: Bool = true,
        checkDevPackages: Bool = true
    ) {
        self.checkBrew = checkBrew
        self.checkMas = checkMas
        self.checkSystem = checkSystem
        self.checkSparkle = checkSparkle
        self.checkDevPackages = checkDevPackages
    }
}
