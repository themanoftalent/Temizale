import Foundation

/// Discovers and uninstalls Homebrew packages (formulae & casks).
public enum HomebrewPackageManager {

    /// Lists all installed packages.
    public static func listInstalled() async -> [InstalledBrewPackage] {
        guard let brew = CommandRunner.which("brew") else { return [] }

        var results: [InstalledBrewPackage] = []

        // Casks
        let casksRes = await CommandRunner.run(brew, arguments: ["list", "--cask", "-1"])
        if casksRes.exitCode == 0 {
            for line in casksRes.stdout.components(separatedBy: .newlines) {
                let name = line.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                results.append(InstalledBrewPackage(name: name, version: "Cask", isCask: true))
            }
        }

        // Formulae
        let formulaeRes = await CommandRunner.run(brew, arguments: ["list", "--formula", "-1"])
        if formulaeRes.exitCode == 0 {
            for line in formulaeRes.stdout.components(separatedBy: .newlines) {
                let name = line.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                results.append(InstalledBrewPackage(name: name, version: "Formula", isCask: false))
            }
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Uninstalls a package.
    public static func uninstall(_ package: InstalledBrewPackage, zap: Bool = false) async -> CommandRunner.Result {
        guard let brew = CommandRunner.which("brew") else {
            return CommandRunner.Result(exitCode: -1, stdout: "", stderr: "Homebrew not found")
        }

        if package.isCask {
            let args = zap ? ["uninstall", "--zap", "--cask", package.name] : ["uninstall", "--cask", package.name]
            return await CommandRunner.run(brew, arguments: args)
        } else {
            return await CommandRunner.run(brew, arguments: ["uninstall", package.name])
        }
    }
}
