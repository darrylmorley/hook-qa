import Foundation
import Observation

// MARK: - MenuBarStatus

enum MenuBarStatus: Sendable {
    case disabled       // grey  — QA not enabled
    case connected      // green — enabled, reachable, last run passed
    case unreachable    // red   — enabled but Ollama not responding
    case lastFailed     // amber — enabled, reachable, last run failed
}

// Box so deinit can invalidate the timer without an actor hop.
private final class TimerBox: @unchecked Sendable {
    var timer: Timer?
    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - StatusMonitor

@Observable
@MainActor
final class StatusMonitor {

    // MARK: - Public state

    private(set) var menuBarStatus: MenuBarStatus = .disabled
    private(set) var isWorking: Bool = false

    // MARK: - Private

    private let settings: SettingsManager
    private let logWatcher: LogWatcher
    private let timerBox = TimerBox()

    // MARK: - Init

    init(settings: SettingsManager, logWatcher: LogWatcher) {
        self.settings = settings
        self.logWatcher = logWatcher

        // Fire immediately, then every 30 seconds
        Task { await self.refresh() }
        scheduleTimer()
    }

    deinit {
        timerBox.invalidate()
    }

    // MARK: - Refresh

    func refresh() async {
        let enabled = settings.config.behaviour.enabled

        // Check if hook process is running
        isWorking = checkHookRunning()

        guard enabled else {
            menuBarStatus = .disabled
            return
        }

        let reachable = await checkOllamaReachability()

        guard reachable else {
            menuBarStatus = .unreachable
            return
        }

        // Check the most recent log entry verdict
        let lastVerdict = logWatcher.entries.first?.verdict
        if lastVerdict == .fail || lastVerdict == .error {
            menuBarStatus = .lastFailed
        } else {
            menuBarStatus = .connected
        }
    }

    // MARK: - Private helpers

    private func scheduleTimer() {
        // Poll faster (2s) to catch hook start/stop quickly
        timerBox.timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refresh()
            }
        }
    }

    private func checkHookRunning() -> Bool {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "hookqa-hook"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func checkOllamaReachability() async -> Bool {
        let model = settings.config.connection.model
        let isCloud = model.hasSuffix(":cloud")
        let baseURL = isCloud ? "https://ollama.com" : settings.config.connection.ollamaUrl
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = isCloud ? 10 : 5

        if let apiKey = settings.config.connection.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = isCloud ? 10 : 5
        config.timeoutIntervalForResource = isCloud ? 10 : 5
        let session = URLSession(configuration: config)

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200..<300).contains(http.statusCode)
            }
            return false
        } catch {
            return false
        }
    }
}
