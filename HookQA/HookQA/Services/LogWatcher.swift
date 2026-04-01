import Foundation
import Observation

// Box that lets deinit cancel the source without an actor hop.
private final class SourceBox: @unchecked Sendable {
    var source: DispatchSourceFileSystemObject?
    func cancel() {
        source?.cancel()
        source = nil
    }
}

@Observable
@MainActor
final class LogWatcher {

    // MARK: - Public state

    /// Parsed log entries, newest first, capped at 200.
    private(set) var entries: [HookQALogEntry] = []

    /// The URL of the log file.
    let logFileURL: URL

    // MARK: - Private

    private let sourceBox = SourceBox()
    private var fileDescriptor: Int32 = -1

    // MARK: - Init

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        logFileURL = homeDir
            .appendingPathComponent(".claude/hooks/hookqa.log")

        startWatching()
        readEntries()
    }

    deinit {
        sourceBox.cancel()
    }

    // MARK: - Public API

    /// Truncates the log file, clearing all entries.
    func clearLog() {
        do {
            let dir = logFileURL.deletingLastPathComponent()
            // Create directory if missing
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            // Truncate (or create) the file
            try Data().write(to: logFileURL, options: .atomic)
        } catch {
            print("[LogWatcher] Failed to clear log: \(error)")
        }
        entries = []
        // Restart the watcher since the file descriptor may have changed
        stopWatching()
        startWatching()
    }

    // MARK: - File watching

    private func startWatching() {
        let path = logFileURL.path

        // If file doesn't exist yet, nothing to watch — we'll check again on next read
        guard FileManager.default.fileExists(atPath: path) else { return }

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            print("[LogWatcher] Could not open file for watching: \(path)")
            return
        }
        fileDescriptor = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )

        src.setEventHandler { [weak self] in
            self?.readEntries()
        }

        src.setCancelHandler {
            close(fd)
        }

        src.resume()
        sourceBox.source = src
    }

    private func stopWatching() {
        sourceBox.cancel()
        fileDescriptor = -1
    }

    // MARK: - Reading

    private func readEntries() {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else {
            entries = []
            return
        }

        do {
            let content = try String(contentsOf: logFileURL, encoding: .utf8)
            let lines = content
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            // Take only the last 200 lines to cap memory usage
            let relevant = lines.suffix(200)

            let decoder = HookQALogEntry.jsonDecoder
            let parsed: [HookQALogEntry] = relevant.compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                do {
                    return try decoder.decode(HookQALogEntry.self, from: data)
                } catch {
                    // Malformed line — skip silently
                    print("[LogWatcher] Skipping malformed line: \(error)")
                    return nil
                }
            }

            // Newest first
            entries = parsed.reversed()
        } catch {
            print("[LogWatcher] Failed to read log file: \(error)")
            entries = []
        }
    }
}
