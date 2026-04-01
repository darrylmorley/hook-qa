import Foundation
import Observation

@Observable
@MainActor
final class SettingsManager {

    // MARK: - Singleton

    static let shared = SettingsManager()

    // MARK: - Published state

    var config: HookQAConfig = HookQAConfig()

    // MARK: - Private

    private let configURL: URL
    private var saveTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let hooksDir = homeDir.appendingPathComponent(".claude/hooks", isDirectory: true)
        configURL = hooksDir.appendingPathComponent("hookqa.json")

        // Ensure directory exists before we try to load
        do {
            try FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)
        } catch {
            print("[SettingsManager] Failed to create hooks directory: \(error)")
        }

        loadConfig()
    }

    // MARK: - Load

    private func loadConfig() {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            // No config file yet — write defaults so the file exists for future edits
            config = HookQAConfig()
            saveImmediately()
            return
        }

        do {
            let data = try Data(contentsOf: configURL)
            let decoded = try JSONDecoder().decode(HookQAConfig.self, from: data)
            config = decoded
        } catch {
            print("[SettingsManager] Malformed config, falling back to defaults: \(error)")
            config = HookQAConfig()
        }
    }

    // MARK: - Save (debounced)

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await self?.saveImmediately()
        }
    }

    func saveImmediately() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL, options: .atomic)
        } catch {
            print("[SettingsManager] Failed to save config: \(error)")
        }
    }

    // MARK: - Reload from disk

    func reload() {
        loadConfig()
    }
}
