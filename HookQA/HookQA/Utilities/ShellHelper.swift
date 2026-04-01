import Foundation

enum ShellError: LocalizedError {
    case launchFailed(Error)
    case nonZeroExit(Int32, String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let e): return "Failed to launch process: \(e.localizedDescription)"
        case .nonZeroExit(let code, let stderr): return "Exit \(code): \(stderr)"
        }
    }
}

struct ShellResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum ShellHelper {

    /// Run a shell command and return its output.
    /// - Parameters:
    ///   - arguments: The command and its arguments (e.g. `["/usr/bin/which", "bun"]`)
    ///   - environment: Optional extra environment variables to merge with the current env
    /// - Returns: `ShellResult` containing stdout, stderr and exit code
    @discardableResult
    static func run(
        _ arguments: [String],
        environment: [String: String]? = nil
    ) throws -> ShellResult {
        guard let executablePath = arguments.first else {
            return ShellResult(stdout: "", stderr: "", exitCode: 0)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = Array(arguments.dropFirst())

        if let extra = environment {
            var env = ProcessInfo.processInfo.environment
            env.merge(extra) { _, new in new }
            process.environment = env
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed(error)
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ShellResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
    }

    /// Convenience: locate a binary using `which`.
    /// Returns the full path, or nil if not found.
    static func which(_ binary: String) -> String? {
        let result = try? run(["/usr/bin/which", binary])
        guard let result, result.exitCode == 0, !result.stdout.isEmpty else { return nil }
        return result.stdout
    }

    /// Make a file executable (chmod +x).
    static func makeExecutable(_ path: String) throws {
        let result = try run(["/bin/chmod", "+x", path])
        if result.exitCode != 0 {
            throw ShellError.nonZeroExit(result.exitCode, result.stderr)
        }
    }
}
