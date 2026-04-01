# HookQA — Phase 5 Kick-off Prompt

Read the spec at `HOOKQA_SPEC.md` to refresh context. You are implementing **Phase 5: Logs & Status**. Phases 1–4 are complete — the app has full config management, hook installation, and the hook script writes JSONL log entries to `~/.claude/hooks/hookqa.log`.

## Deliverables

1. **HookQALogEntry** (`Models/HookQALogEntry.swift`)
   - Update the stub from Phase 1 into a full Codable struct matching the JSONL format:
     ```
     timestamp: Date
     project: String
     model: String
     verdict: Verdict (enum: pass, fail, error, skipped)
     findings: Int
     criticals: Int
     warnings: Int
     summary: String
     durationMs: Int
     ```
   - The `Verdict` enum should be `Codable` with raw string values: "PASS", "FAIL", "ERROR", "SKIPPED"
   - Custom date decoding for ISO 8601 with fractional seconds

2. **LogWatcher** (`Services/LogWatcher.swift`)
   - `@Observable` class
   - Watches `~/.claude/hooks/hookqa.log` for changes using `DispatchSource.makeFileSystemObjectSource` (FSEvents)
   - On change, re-reads and parses the file
   - Exposes `entries: [HookQALogEntry]` — parsed from JSONL, sorted newest first
   - Caps at 200 entries in memory (the file may have more — just read the last 200 lines)
   - Handles the file not existing yet (empty state, starts watching when created)
   - Handles malformed lines gracefully (skip them, don't crash)
   - Provides `clearLog()` — truncates the file to empty
   - Provides `logFileURL: URL` — for "Open in Finder" functionality
   - Starts watching on init, stops on deinit

3. **LogsTab** (`Views/LogsTab.swift`)
   - Replace the placeholder Logs tab with a full log viewer
   - **Empty state:** When no log entries, show a centered message: "No QA evaluations yet. Logs will appear here after your first hook run."
   - **Log list:** Scrollable list of entries, each row showing:
     - **Verdict badge** — coloured rounded label: PASS (green), FAIL (red), ERROR (grey), SKIPPED (muted/secondary)
     - **Project name** — primary text
     - **Timestamp** — relative time (e.g. "2 min ago", "1 hour ago", "Yesterday"). Use `RelativeDateTimeFormatter`.
     - **Finding count** — e.g. "3 findings" or "0 findings"
     - **Duration** — e.g. "45.2s" (convert from durationMs)
   - **Expandable rows:** Tapping a row expands it to show:
     - Model name (monospaced)
     - Full summary text
     - Breakdown: "X critical, Y warnings" 
   - **Toolbar/footer actions:**
     - "Clear Logs" button — shows a confirmation alert ("Clear all QA log entries? This cannot be undone."), then calls LogWatcher.clearLog()
     - "Open in Finder" button — opens the log file location via `NSWorkspace.shared.activatingFileViewerSelecting`
   - List should update live when new entries appear (via LogWatcher's file watching)

4. **StatusMonitor** (`Services/StatusMonitor.swift`)
   - `@Observable` class
   - Runs a timer every 30 seconds
   - On each tick:
     - Checks Ollama reachability: quick `GET /api/tags` with 5s timeout (use OllamaClient)
     - Reads the last log entry from LogWatcher
   - Exposes `menuBarStatus: MenuBarStatus` enum:
     - `.disabled` — QA is disabled in config → grey icon
     - `.connected` — QA enabled + Ollama reachable → green icon
     - `.unreachable` — QA enabled + Ollama not reachable → red icon
     - `.lastFailed` — QA enabled + Ollama reachable + last log entry was FAIL → amber icon
   - Fires immediately on init, then every 30s
   - Also fires when config changes (e.g. endpoint or enabled state changes)

5. **Dynamic menubar icon**
   - Update `HookQAApp.swift` to use StatusMonitor
   - The NSStatusItem icon should change colour based on `menuBarStatus`:
     - `.disabled` → `checkmark.shield` in secondary/grey colour
     - `.connected` → `checkmark.shield.fill` in green
     - `.unreachable` → `exclamationmark.shield.fill` in red
     - `.lastFailed` → `checkmark.shield.fill` in amber/orange
   - Use SF Symbols with appropriate rendering mode for colour tinting

## Rules

- LogWatcher must handle the log file not existing — don't crash, show empty state
- File watching should be efficient — don't poll, use DispatchSource
- RelativeDateTimeFormatter for timestamps — no manual date formatting
- The log list should feel responsive — 200 entries should scroll smoothly
- StatusMonitor should not retain strong references that prevent deallocation — use `[weak self]` in timer callbacks
- Keep the status polling lightweight — the GET request is just a health check, not a full model fetch
- Do not modify the hook script, HookInstaller, or config model unless fixing a bug
- Do not implement Phase 6
