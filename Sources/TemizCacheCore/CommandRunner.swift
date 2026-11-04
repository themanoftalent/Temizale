import Foundation

/// Executes external commands with appropriate PATH and environment settings.
public enum CommandRunner {
    public struct Result: Sendable {
        public let exitCode: Int32
        public let stdout: String
        public let stderr: String

        public var output: String {
            if stderr.isEmpty { return stdout }
            if stdout.isEmpty { return stderr }
            return stdout + "\n" + stderr
        }
    }

    /// Resolves the default augmented PATH containing standard Homebrew and system locations.
    public static var defaultPath: String {
        let paths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            ProcessInfo.processInfo.environment["HOME"].map { "\($0)/.cargo/bin" } ?? "",
            ProcessInfo.processInfo.environment["PATH"] ?? ""
        ]
        return paths.filter { !$0.isEmpty }.joined(separator: ":")
    }

    /// Finds the absolute path of an executable.
    public static func which(_ name: String) -> String? {
        // Fast direct checks for common utilities
        let candidates: [String]
        switch name {
        case "brew":
            candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        case "mas":
            candidates = ["/opt/homebrew/bin/mas", "/usr/local/bin/mas"]
        case "softwareupdate":
            candidates = ["/usr/sbin/softwareupdate"]
        case "npm":
            candidates = ["/opt/homebrew/bin/npm", "/usr/local/bin/npm", "/usr/bin/npm"]
        case "pip3", "pip":
            candidates = ["/opt/homebrew/bin/pip3", "/usr/local/bin/pip3", "/usr/bin/pip3"]
        default:
            candidates = []
        }

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallback: search defaultPath
        for dir in defaultPath.split(separator: ":") {
            let fullPath = URL(fileURLWithPath: String(dir)).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }

        return nil
    }

    /// Runs a process synchronously on a background thread and returns its result.
    public static func run(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) async -> Result {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                var env = ProcessInfo.processInfo.environment
                env["PATH"] = defaultPath
                env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
                env["HOMEBREW_NO_ENV_HINTS"] = "1"
                for (k, v) in environment {
                    env[k] = v
                }
                process.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    let stdout = String(data: outData, encoding: .utf8) ?? ""
                    let stderr = String(data: errData, encoding: .utf8) ?? ""
                    continuation.resume(returning: Result(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr))
                } catch {
                    continuation.resume(returning: Result(exitCode: -1, stdout: "", stderr: error.localizedDescription))
                }
            }
        }
    }

    /// Runs a process asynchronously and streams output line-by-line via handler.
    public static func stream(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        onOutput: @escaping @Sendable (String) -> Void
    ) async -> Int32 {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                var env = ProcessInfo.processInfo.environment
                env["PATH"] = defaultPath
                env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
                env["HOMEBREW_NO_ENV_HINTS"] = "1"
                for (k, v) in environment {
                    env[k] = v
                }
                process.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                let queue = DispatchQueue(label: "com.themanoftalent.commandrunner.stream")

                outPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                    queue.async {
                        for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                            onOutput(line)
                        }
                    }
                }

                errPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                    queue.async {
                        for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                            onOutput(line)
                        }
                    }
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: process.terminationStatus)
                } catch {
                    onOutput("Error launching \(executable): \(error.localizedDescription)")
                    continuation.resume(returning: -1)
                }
            }
        }
    }
}
