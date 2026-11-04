import Foundation
import AppKit

/// Scans installed applications and package managers to find outdated items.
public enum SoftwareUpdateScanner {

    // MARK: - Homebrew JSON Models

    private struct BrewOutdatedPayload: Decodable {
        struct FormulaEntry: Decodable {
            let name: String
            let installed_versions: [String]?
            let current_version: String
            let pinned: Bool?
        }
        struct CaskEntry: Decodable {
            let name: String
            let installed_versions: [String]?
            let current_version: String
        }

        let formulae: [FormulaEntry]?
        let casks: [CaskEntry]?
    }

    // MARK: - Public Scanning Entrypoint

    public static func scan(options: UpdateCheckOptions = UpdateCheckOptions()) async -> [SoftwareUpdateItem] {
        var results: [SoftwareUpdateItem] = []

        await withTaskGroup(of: [SoftwareUpdateItem].self) { group in
            if options.checkBrew {
                group.addTask { await scanHomebrew() }
            }
            if options.checkMas {
                group.addTask { await scanMas() }
            }
            if options.checkSystem {
                group.addTask { await scanSystem() }
            }
            if options.checkDevPackages {
                group.addTask { await scanNpm() }
                group.addTask { await scanPip() }
            }
            if options.checkSparkle {
                group.addTask { await scanSparkleApps() }
            }

            for await items in group {
                results.append(contentsOf: items)
            }
        }

        // De-duplicate by ID and sort alphabetically by displayName
        var seen = Set<String>()
        var unique: [SoftwareUpdateItem] = []
        for item in results {
            if seen.insert(item.id).inserted {
                unique.append(item)
            }
        }
        return unique.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - Homebrew Scanner

    public static func scanHomebrew() async -> [SoftwareUpdateItem] {
        guard let brew = CommandRunner.which("brew") else { return [] }

        let res = await CommandRunner.run(brew, arguments: ["outdated", "--json=v2"])
        guard res.exitCode == 0, !res.stdout.isEmpty else { return [] }

        // Homebrew can prepend progress lines like "==> Downloading..." before JSON
        guard let jsonStartIndex = res.stdout.firstIndex(of: "{") else { return [] }
        let jsonString = String(res.stdout[jsonStartIndex...])
        guard let data = jsonString.data(using: .utf8) else { return [] }

        var items: [SoftwareUpdateItem] = []
        do {
            let payload = try JSONDecoder().decode(BrewOutdatedPayload.self, from: data)

            if let casks = payload.casks {
                for c in casks {
                    let installed = c.installed_versions?.joined(separator: ", ") ?? "Installed"
                    let cleanName = c.name.components(separatedBy: "/").last ?? c.name
                    items.append(SoftwareUpdateItem(
                        id: "brew-cask:\(c.name)",
                        name: c.name,
                        displayName: cleanName.capitalizedWords,
                        installedVersion: installed,
                        latestVersion: c.current_version,
                        source: .brewCask,
                        rawIdentifier: c.name
                    ))
                }
            }

            if let formulae = payload.formulae {
                for f in formulae {
                    let installed = f.installed_versions?.joined(separator: ", ") ?? "Installed"
                    items.append(SoftwareUpdateItem(
                        id: "brew-formula:\(f.name)",
                        name: f.name,
                        displayName: f.name,
                        installedVersion: installed,
                        latestVersion: f.current_version,
                        source: .brewFormula,
                        rawIdentifier: f.name
                    ))
                }
            }
        } catch {
            // Failed to parse JSON
        }

        return items
    }

    // MARK: - Mac App Store Scanner (mas)

    public static func scanMas() async -> [SoftwareUpdateItem] {
        guard let mas = CommandRunner.which("mas") else { return [] }

        let res = await CommandRunner.run(mas, arguments: ["outdated"])
        guard res.exitCode == 0, !res.stdout.isEmpty else { return [] }

        // Expected line format:
        // 497799835 Xcode (15.2 -> 15.3)
        var items: [SoftwareUpdateItem] = []
        for line in res.stdout.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let pattern = #"^(\d+)\s+(.+?)\s+\((.+?)\s+->\s+(.+?)\)$"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = trimmed as NSString
            let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: ns.length))
            if let m = matches.first, m.numberOfRanges >= 5 {
                let id = ns.substring(with: m.range(at: 1))
                let name = ns.substring(with: m.range(at: 2))
                let installed = ns.substring(with: m.range(at: 3))
                let latest = ns.substring(with: m.range(at: 4))

                items.append(SoftwareUpdateItem(
                    id: "mas:\(id)",
                    name: name,
                    displayName: name,
                    installedVersion: installed,
                    latestVersion: latest,
                    source: .mas,
                    rawIdentifier: id
                ))
            }
        }
        return items
    }

    // MARK: - macOS System Scanner (softwareupdate)

    public static func scanSystem() async -> [SoftwareUpdateItem] {
        guard let su = CommandRunner.which("softwareupdate") else { return [] }

        let res = await CommandRunner.run(su, arguments: ["-l"])
        guard !res.output.isEmpty else { return [] }

        var items: [SoftwareUpdateItem] = []
        var currentLabel: String?
        var currentTitle: String?
        var currentVersion: String?

        func flushCurrent() {
            if let label = currentLabel {
                let name = currentTitle ?? label
                let version = currentVersion ?? "Update Available"
                items.append(SoftwareUpdateItem(
                    id: "system:\(label)",
                    name: label,
                    displayName: name,
                    installedVersion: "Current macOS",
                    latestVersion: version,
                    source: .system,
                    rawIdentifier: label
                ))
            }
            currentLabel = nil
            currentTitle = nil
            currentVersion = nil
        }

        for line in res.output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("* Label: ") {
                flushCurrent()
                currentLabel = String(trimmed.dropFirst("* Label: ".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Title: ") {
                // e.g. "Title: macOS Sonoma 14.5, Version: 14.5, ..."
                let parts = trimmed.components(separatedBy: ",")
                for part in parts {
                    let p = part.trimmingCharacters(in: .whitespaces)
                    if p.hasPrefix("Title: ") {
                        currentTitle = String(p.dropFirst("Title: ".count))
                    } else if p.hasPrefix("Version: ") {
                        currentVersion = String(p.dropFirst("Version: ".count))
                    }
                }
            }
        }
        flushCurrent()

        return items
    }

    // MARK: - npm Scanner

    public static func scanNpm() async -> [SoftwareUpdateItem] {
        guard let npm = CommandRunner.which("npm") else { return [] }

        let res = await CommandRunner.run(npm, arguments: ["outdated", "-g", "--json"])
        guard !res.stdout.isEmpty else { return [] }

        guard let jsonStartIndex = res.stdout.firstIndex(of: "{") else { return [] }
        let jsonString = String(res.stdout[jsonStartIndex...])
        guard let data = jsonString.data(using: .utf8) else { return [] }

        struct NpmPackage: Decodable {
            let current: String?
            let latest: String?
        }

        var items: [SoftwareUpdateItem] = []
        if let dict = try? JSONDecoder().decode([String: NpmPackage].self, from: data) {
            for (pkgName, info) in dict {
                let current = info.current ?? "Installed"
                let latest = info.latest ?? "Latest"
                items.append(SoftwareUpdateItem(
                    id: "npm:\(pkgName)",
                    name: pkgName,
                    displayName: "\(pkgName) (npm)",
                    installedVersion: current,
                    latestVersion: latest,
                    source: .npm,
                    rawIdentifier: pkgName
                ))
            }
        }
        return items
    }

    // MARK: - pip Scanner

    public static func scanPip() async -> [SoftwareUpdateItem] {
        guard let pip = CommandRunner.which("pip3") ?? CommandRunner.which("pip") else { return [] }

        let res = await CommandRunner.run(pip, arguments: ["list", "--outdated", "--format=json"])
        guard res.exitCode == 0, !res.stdout.isEmpty else { return [] }

        guard let jsonStartIndex = res.stdout.firstIndex(of: "[") else { return [] }
        let jsonString = String(res.stdout[jsonStartIndex...])
        guard let data = jsonString.data(using: .utf8) else { return [] }

        struct PipPackage: Decodable {
            let name: String
            let version: String
            let latest_version: String
        }

        var items: [SoftwareUpdateItem] = []
        if let list = try? JSONDecoder().decode([PipPackage].self, from: data) {
            for p in list {
                items.append(SoftwareUpdateItem(
                    id: "pip:\(p.name)",
                    name: p.name,
                    displayName: "\(p.name) (pip)",
                    installedVersion: p.version,
                    latestVersion: p.latest_version,
                    source: .pip,
                    rawIdentifier: p.name
                ))
            }
        }
        return items
    }

    // MARK: - Sparkle Direct Applications Scanner

    public static func scanSparkleApps() async -> [SoftwareUpdateItem] {
        let appDirs = ["/Applications", ("~/Applications" as NSString).expandingTildeInPath]
        var appsWithFeeds: [(name: String, path: String, feedURL: URL, version: String)] = []

        for dir in appDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let fullPath = (dir as NSString).appendingPathComponent(item)
                let infoPlistPath = (fullPath as NSString).appendingPathComponent("Contents/Info.plist")
                guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: infoPlistPath)),
                      let plist = (try? PropertyListSerialization.propertyList(from: plistData, format: nil)) as? [String: Any],
                      let feedURLString = plist["SUFeedURL"] as? String,
                      let feedURL = URL(string: feedURLString) else { continue }

                let name = plist["CFBundleDisplayName"] as? String
                    ?? plist["CFBundleName"] as? String
                    ?? (item as NSString).deletingPathExtension
                let shortVersion = plist["CFBundleShortVersionString"] as? String ?? "0"
                appsWithFeeds.append((name: name, path: fullPath, feedURL: feedURL, version: shortVersion))
            }
        }

        var results: [SoftwareUpdateItem] = []
        await withTaskGroup(of: SoftwareUpdateItem?.self) { group in
            for app in appsWithFeeds {
                group.addTask {
                    return await checkSparkleFeed(app: app)
                }
            }
            for await item in group {
                if let item { results.append(item) }
            }
        }
        return results
    }

    private static func checkSparkleFeed(app: (name: String, path: String, feedURL: URL, version: String)) async -> SoftwareUpdateItem? {
        var request = URLRequest(url: app.feedURL)
        request.timeoutInterval = 6.0
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let xml = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Quick regex for Sparkle enclosure attributes
        let versionPattern = #"sparkle:shortVersionString="([^"]+)""#
        let fallbackPattern = #"sparkle:version="([^"]+)""#

        var latestVersion: String?
        if let regex = try? NSRegularExpression(pattern: versionPattern) {
            let ns = xml as NSString
            if let match = regex.firstMatch(in: xml, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges > 1 {
                latestVersion = ns.substring(with: match.range(at: 1))
            }
        }
        if latestVersion == nil, let regex = try? NSRegularExpression(pattern: fallbackPattern) {
            let ns = xml as NSString
            if let match = regex.firstMatch(in: xml, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges > 1 {
                latestVersion = ns.substring(with: match.range(at: 1))
            }
        }

        guard let latest = latestVersion, isVersion(latest, newerThan: app.version) else {
            return nil
        }

        return SoftwareUpdateItem(
            id: "sparkle:\(app.name)",
            name: app.name,
            displayName: app.name,
            installedVersion: app.version,
            latestVersion: latest,
            source: .sparkle,
            rawIdentifier: app.path,
            appBundlePath: app.path,
            releaseNotesURL: app.feedURL
        )
    }

    /// Compares two numeric version strings like "1.2.3" vs "1.2.0".
    public static func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        if v1 == v2 { return false }
        let c1 = v1.split(separator: ".").compactMap { Int($0.prefix(while: { $0.isNumber })) }
        let c2 = v2.split(separator: ".").compactMap { Int($0.prefix(while: { $0.isNumber })) }

        let count = max(c1.count, c2.count)
        for i in 0..<count {
            let num1 = i < c1.count ? c1[i] : 0
            let num2 = i < c2.count ? c2[i] : 0
            if num1 > num2 { return true }
            if num1 < num2 { return false }
        }
        return v1.localizedStandardCompare(v2) == .orderedDescending
    }
}

private extension String {
    var capitalizedWords: String {
        self.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
