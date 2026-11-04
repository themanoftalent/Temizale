import Foundation

/// Built-in cache definitions plus optional user additions.
///
/// Users can add their own entries in
/// `~/Library/Application Support/AleTemizCache/targets.json`, an array of `CacheTarget`
/// objects. An entry whose `id` matches a built-in replaces it.
public enum Catalog {
    public static let builtIn: [CacheTarget] = [
        // Developer tools
        CacheTarget(
            id: "xcode.deriveddata",
            title: "Xcode DerivedData",
            summary: "Build products and index data. Xcode rebuilds it on the next build.",
            kind: .developer,
            paths: ["~/Library/Developer/Xcode/DerivedData"]
        ),
        CacheTarget(
            id: "xcode.devicesupport",
            title: "Xcode iOS DeviceSupport",
            summary: "Debug symbols copied from connected iPhones and iPads.",
            kind: .developer,
            paths: [
                "~/Library/Developer/Xcode/iOS DeviceSupport",
                "~/Library/Developer/Xcode/watchOS DeviceSupport",
                "~/Library/Developer/Xcode/tvOS DeviceSupport"
            ],
            caution: "Xcode copies these again the next time you connect a device."
        ),
        CacheTarget(
            id: "coresimulator.caches",
            title: "Simulator Caches",
            summary: "Dyld and runtime caches for iOS simulators.",
            kind: .developer,
            paths: ["~/Library/Developer/CoreSimulator/Caches"]
        ),
        CacheTarget(
            id: "swiftpm",
            title: "Swift Package Manager",
            summary: "Downloaded package repositories and manifests.",
            kind: .packageManager,
            paths: ["~/Library/Caches/org.swift.swiftpm"]
        ),
        CacheTarget(
            id: "jetbrains",
            title: "JetBrains IDEs",
            summary: "Index and cache folders for IntelliJ, PyCharm, CLion and friends.",
            kind: .developer,
            paths: ["~/Library/Caches/JetBrains"],
            caution: "The IDE re-indexes open projects on next launch."
        ),
        CacheTarget(
            id: "vscode",
            title: "Visual Studio Code",
            summary: "Compiled code, GPU and HTTP caches used by the editor.",
            kind: .developer,
            paths: [
                "~/Library/Application Support/Code/Cache",
                "~/Library/Application Support/Code/CachedData",
                "~/Library/Application Support/Code/Code Cache",
                "~/Library/Application Support/Code/GPUCache"
            ],
            caution: "Quit VS Code first."
        ),

        // Package managers
        CacheTarget(
            id: "homebrew",
            title: "Homebrew",
            summary: "Downloaded bottles and source archives kept after installs.",
            kind: .packageManager,
            paths: ["~/Library/Caches/Homebrew"]
        ),
        CacheTarget(
            id: "cocoapods",
            title: "CocoaPods",
            summary: "Cached pod specs and downloaded pod sources.",
            kind: .packageManager,
            paths: ["~/Library/Caches/CocoaPods"]
        ),
        CacheTarget(
            id: "carthage",
            title: "Carthage",
            summary: "Cached dependency checkouts and binaries.",
            kind: .packageManager,
            paths: ["~/Library/Caches/org.carthage.CarthageKit"]
        ),
        CacheTarget(
            id: "npm",
            title: "npm",
            summary: "Content-addressed package cache and install logs.",
            kind: .packageManager,
            paths: ["~/.npm/_cacache", "~/.npm/_logs"]
        ),
        CacheTarget(
            id: "yarn",
            title: "Yarn",
            summary: "Offline mirror of downloaded packages.",
            kind: .packageManager,
            paths: ["~/Library/Caches/Yarn"]
        ),
        CacheTarget(
            id: "pnpm",
            title: "pnpm",
            summary: "Metadata cache for the pnpm resolver.",
            kind: .packageManager,
            paths: ["~/Library/Caches/pnpm"]
        ),
        CacheTarget(
            id: "pip",
            title: "pip",
            summary: "Downloaded wheels and HTTP responses from PyPI.",
            kind: .packageManager,
            paths: ["~/Library/Caches/pip"]
        ),
        CacheTarget(
            id: "gradle",
            title: "Gradle",
            summary: "Downloaded dependencies and build caches.",
            kind: .packageManager,
            paths: ["~/.gradle/caches"],
            caution: "Offline builds fail until Gradle downloads dependencies again."
        ),
        CacheTarget(
            id: "go",
            title: "Go Build Cache",
            summary: "Compiled package objects reused across Go builds.",
            kind: .packageManager,
            paths: ["~/Library/Caches/go-build"]
        ),
        CacheTarget(
            id: "cargo",
            title: "Cargo Registry",
            summary: "Compressed crate archives downloaded by Cargo.",
            kind: .packageManager,
            paths: ["~/.cargo/registry/cache"]
        ),

        // Browsers. Only true cache folders, never profile folders that hold
        // bookmarks, passwords or history.
        CacheTarget(
            id: "chrome",
            title: "Google Chrome",
            summary: "Disk cache for web pages, images and scripts.",
            kind: .browser,
            paths: ["~/Library/Caches/Google/Chrome", "~/Library/Caches/com.google.Chrome"]
        ),
        CacheTarget(
            id: "firefox",
            title: "Mozilla Firefox",
            summary: "Disk cache for web pages, images and scripts.",
            kind: .browser,
            paths: ["~/Library/Caches/Firefox", "~/Library/Caches/org.mozilla.firefox"]
        ),
        CacheTarget(
            id: "edge",
            title: "Microsoft Edge",
            summary: "Disk cache for web pages, images and scripts.",
            kind: .browser,
            paths: ["~/Library/Caches/Microsoft Edge"]
        ),
        CacheTarget(
            id: "brave",
            title: "Brave",
            summary: "Disk cache for web pages, images and scripts.",
            kind: .browser,
            paths: ["~/Library/Caches/BraveSoftware"]
        ),

        // Apps
        CacheTarget(
            id: "spotify",
            title: "Spotify",
            summary: "Streamed audio cache and artwork.",
            kind: .app,
            paths: ["~/Library/Caches/com.spotify.client"],
            caution: "Downloaded offline playlists live elsewhere and stay untouched."
        ),
        CacheTarget(
            id: "slack",
            title: "Slack",
            summary: "Web content and code caches used by the desktop app.",
            kind: .app,
            paths: [
                "~/Library/Application Support/Slack/Cache",
                "~/Library/Application Support/Slack/Code Cache"
            ],
            caution: "Quit Slack first."
        ),

        // Logs
        CacheTarget(
            id: "homebrew.logs",
            title: "Homebrew Logs",
            summary: "Build logs from formula installs.",
            kind: .logs,
            paths: ["~/Library/Logs/Homebrew"]
        ),
        CacheTarget(
            id: "diagnostic.reports",
            title: "User Crash Reports",
            summary: "Crash and hang reports written for your user account.",
            kind: .logs,
            paths: ["~/Library/Logs/DiagnosticReports"],
            caution: "Keep these if you plan to file a bug report."
        )
    ]

    public static func userFileURL(home: URL) -> URL {
        home.appendingPathComponent("Library/Application Support/Temizale/targets.json")
    }

    /// Location used before the Temizale rename. Read only when the new file is absent.
    public static func legacyUserFileURL(home: URL) -> URL {
        home.appendingPathComponent("Library/Application Support/AleTemizCache/targets.json")
    }

    public struct LoadResult: Sendable {
        public let targets: [CacheTarget]
        public let warnings: [String]
    }

    /// Merges built-ins with the user file and drops any path that fails `PathPolicy`.
    public static func load(home: URL, fileManager: FileManager = .default) -> LoadResult {
        var warnings: [String] = []
        var byID: [String: CacheTarget] = [:]
        var order: [String] = []

        func add(_ target: CacheTarget) {
            if byID[target.id] == nil { order.append(target.id) }
            byID[target.id] = target
        }

        builtIn.forEach(add)

        var userURL = userFileURL(home: home)
        if !fileManager.fileExists(atPath: userURL.path) {
            if fileManager.fileExists(atPath: legacyUserFileURL(home: home).path) {
                userURL = legacyUserFileURL(home: home)
            } else {
                let older = home.appendingPathComponent("Library/Application Support/TemizCache/targets.json")
                if fileManager.fileExists(atPath: older.path) {
                    userURL = older
                }
            }
        }
        if fileManager.fileExists(atPath: userURL.path) {
            do {
                let data = try Data(contentsOf: userURL)
                let extra = try JSONDecoder().decode([CacheTarget].self, from: data)
                extra.forEach(add)
            } catch {
                warnings.append("Could not read \(userURL.path): \(error.localizedDescription)")
            }
        }

        var result: [CacheTarget] = []
        for id in order {
            guard let target = byID[id] else { continue }
            var safePaths: [String] = []
            for path in target.paths {
                let url = PathPolicy.expand(path, home: home)
                do {
                    try PathPolicy.validate(url, home: home)
                    safePaths.append(path)
                } catch {
                    warnings.append("\(target.title): \(error)")
                }
            }
            guard !safePaths.isEmpty else { continue }
            result.append(CacheTarget(
                id: target.id,
                title: target.title,
                summary: target.summary,
                kind: target.kind,
                paths: safePaths,
                caution: target.caution
            ))
        }
        return LoadResult(targets: result, warnings: warnings)
    }
}
