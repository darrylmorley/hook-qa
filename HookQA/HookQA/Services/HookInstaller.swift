import Foundation
import Observation

@Observable
@MainActor
final class HookInstaller {

    // MARK: - Singleton

    static let shared = HookInstaller()

    // MARK: - State

    var hookScriptInstalled: Bool = false
    var hookRegistered: Bool = false
    var bunAvailable: Bool = false
    var installedVersion: String? = nil
    var lastError: String? = nil

    // Reads version from the second line of the bundled script at init time.
    // This is safe to do synchronously since it's a bundle resource.
    let bundledVersion: String = {
        guard let path = Bundle.main.path(forResource: "hookqa-hook", ofType: "ts") else {
            return "unknown"
        }
        return HookInstaller.readVersionFromFile(at: path) ?? "unknown"
    }()

    var updateAvailable: Bool {
        guard hookScriptInstalled, let installed = installedVersion else { return false }
        return installed != bundledVersion
    }

    // MARK: - Paths

    private let homeDir = FileManager.default.homeDirectoryForCurrentUser
    private var hooksDir: URL { homeDir.appendingPathComponent(".claude/hooks", isDirectory: true) }
    private var hookScriptURL: URL { hooksDir.appendingPathComponent("hookqa-hook.ts") }
    private var settingsURL: URL { homeDir.appendingPathComponent(".claude/settings.json") }

    // MARK: - Init

    private init() {}

    // MARK: - Status

    func refreshStatus() {
        // Check bun
        bunAvailable = ShellHelper.which("bun") != nil

        // Check hook script on disk
        let scriptExists = FileManager.default.fileExists(atPath: hookScriptURL.path)
        hookScriptInstalled = scriptExists

        if scriptExists {
            installedVersion = Self.readVersionFromFile(at: hookScriptURL.path)
        } else {
            installedVersion = nil
        }

        // Check settings.json registration
        hookRegistered = isHookRegisteredInSettings()
    }

    // MARK: - Install

    func install(timeout: Int = 120) async {
        lastError = nil
        do {
            try ensureHooksDirectory()
            try copyBundledScript()
            try ShellHelper.makeExecutable(hookScriptURL.path)
            try appendHookToSettings(timeout: timeout)
            refreshStatus()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Uninstall

    func uninstall() async {
        lastError = nil
        do {
            // Remove script file if it exists
            if FileManager.default.fileExists(atPath: hookScriptURL.path) {
                try FileManager.default.removeItem(at: hookScriptURL)
            }
            try removeHookFromSettings()
            refreshStatus()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Update

    func update(timeout: Int = 120) async {
        lastError = nil
        do {
            try ensureHooksDirectory()
            try copyBundledScript()
            try ShellHelper.makeExecutable(hookScriptURL.path)
            // Update the timeout in existing registration
            try updateTimeoutInSettings(timeout: timeout)
            refreshStatus()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Private helpers

    private func ensureHooksDirectory() throws {
        try FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)
    }

    private func copyBundledScript() throws {
        guard let bundledPath = Bundle.main.path(forResource: "hookqa-hook", ofType: "ts") else {
            throw HookInstallerError.bundledScriptNotFound
        }

        let destination = hookScriptURL

        // Overwrite if already exists
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.copyItem(
            atPath: bundledPath,
            toPath: destination.path
        )
    }

    // MARK: - settings.json manipulation

    /// Read and parse settings.json, creating it as `{}` if absent.
    private func readSettings() throws -> NSMutableDictionary {
        if !FileManager.default.fileExists(atPath: settingsURL.path) {
            // Create parent directory if needed
            let claudeDir = homeDir.appendingPathComponent(".claude", isDirectory: true)
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            // Write empty object
            try "{}".write(to: settingsURL, atomically: true, encoding: .utf8)
        }

        let data = try Data(contentsOf: settingsURL)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? NSMutableDictionary else {
            throw HookInstallerError.settingsParseError
        }
        return dict
    }

    private func writeSettings(_ dict: NSMutableDictionary) throws {
        let data = try JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: settingsURL, options: .atomic)
    }

    /// Navigate to hooks.Stop array, creating the path if needed.
    private func stopArray(in dict: NSMutableDictionary) -> NSMutableArray {
        let hooks: NSMutableDictionary
        if let existing = dict["hooks"] as? NSMutableDictionary {
            hooks = existing
        } else {
            let newHooks = NSMutableDictionary()
            dict["hooks"] = newHooks
            hooks = newHooks
        }

        if let existing = hooks["Stop"] as? NSMutableArray {
            return existing
        } else {
            let newStop = NSMutableArray()
            hooks["Stop"] = newStop
            return newStop
        }
    }

    private func appendHookToSettings(timeout: Int) throws {
        let dict = try readSettings()

        let stop = stopArray(in: dict)

        // Check if a hookqa entry already exists — skip if so
        for item in stop {
            if let entry = item as? NSDictionary,
               let hooksList = entry["hooks"] as? NSArray {
                for hookItem in hooksList {
                    if let h = hookItem as? NSDictionary,
                       let cmd = h["command"] as? String,
                       cmd.contains("hookqa") {
                        // Already registered
                        return
                    }
                }
            }
        }

        let newEntry: NSDictionary = [
            "hooks": [
                [
                    "type": "command",
                    "command": "bun ~/.claude/hooks/hookqa-hook.ts",
                    "timeout": timeout
                ]
            ]
        ]
        stop.add(newEntry)

        try writeSettings(dict)
    }

    private func removeHookFromSettings() throws {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }

        let dict = try readSettings()

        guard let hooks = dict["hooks"] as? NSMutableDictionary,
              let stop = hooks["Stop"] as? NSMutableArray else {
            return
        }

        // Find and remove the entry whose command contains "hookqa"
        var indexToRemove: Int? = nil
        for (index, item) in stop.enumerated() {
            if let entry = item as? NSDictionary,
               let hooksList = entry["hooks"] as? NSArray {
                for hookItem in hooksList {
                    if let h = hookItem as? NSDictionary,
                       let cmd = h["command"] as? String,
                       cmd.contains("hookqa") {
                        indexToRemove = index
                        break
                    }
                }
            }
            if indexToRemove != nil { break }
        }

        if let idx = indexToRemove {
            stop.removeObject(at: idx)
        }

        // Clean up empty Stop / hooks
        if stop.count == 0 {
            hooks.removeObject(forKey: "Stop")
        }
        if hooks.count == 0 {
            dict.removeObject(forKey: "hooks")
        }

        try writeSettings(dict)
    }

    private func updateTimeoutInSettings(timeout: Int) throws {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }

        let dict = try readSettings()

        guard let hooks = dict["hooks"] as? NSMutableDictionary,
              let stop = hooks["Stop"] as? NSMutableArray else {
            return
        }

        for item in stop {
            if let entry = item as? NSMutableDictionary,
               let hooksList = entry["hooks"] as? NSMutableArray {
                for hookItem in hooksList {
                    if let h = hookItem as? NSMutableDictionary,
                       let cmd = h["command"] as? String,
                       cmd.contains("hookqa") {
                        h["timeout"] = timeout
                    }
                }
            }
        }

        try writeSettings(dict)
    }

    private func isHookRegisteredInSettings() -> Bool {
        guard FileManager.default.fileExists(atPath: settingsURL.path),
              let data = try? Data(contentsOf: settingsURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? NSDictionary,
              let hooks = dict["hooks"] as? NSDictionary,
              let stop = hooks["Stop"] as? NSArray else {
            return false
        }

        for item in stop {
            if let entry = item as? NSDictionary,
               let hooksList = entry["hooks"] as? NSArray {
                for hookItem in hooksList {
                    if let h = hookItem as? NSDictionary,
                       let cmd = h["command"] as? String,
                       cmd.contains("hookqa") {
                        return true
                    }
                }
            }
        }
        return false
    }

    // MARK: - Version parsing

    /// Read the second line of a file and extract the version string.
    /// Expected format: `// hookqa-hook v1.0.0`
    static func readVersionFromFile(at path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { handle.closeFile() }

        // Read enough bytes to get the first two lines
        let data = handle.readData(ofLength: 512)
        guard let text = String(data: data, encoding: .utf8) else { return nil }

        let lines = text.components(separatedBy: "\n")
        guard lines.count >= 2 else { return nil }

        let secondLine = lines[1].trimmingCharacters(in: .whitespaces)
        // Parse "// hookqa-hook v1.0.0"
        let parts = secondLine.components(separatedBy: " ")
        for part in parts {
            if part.hasPrefix("v") && part.count > 1 {
                return part
            }
        }
        return nil
    }
}

// MARK: - Errors

enum HookInstallerError: LocalizedError {
    case bundledScriptNotFound
    case settingsParseError

    var errorDescription: String? {
        switch self {
        case .bundledScriptNotFound:
            return "Bundled hook script not found in app resources."
        case .settingsParseError:
            return "Could not parse ~/.claude/settings.json."
        }
    }
}
