# HookQA — macOS Menubar App Spec

## Overview

**HookQA** is a macOS menubar app that manages the Claude Code QA evaluation pipeline. It configures and installs a Claude Code Stop hook that sends code changes to an Ollama model (local or cloud) for automated QA review. If the reviewer finds critical issues, Claude Code is blocked from stopping and receives findings as actionable feedback.

The app replaces the previous setup of manual env vars, a standalone Bun hook script, and a browser-based React admin panel with a single native app that owns the full lifecycle: configuration, hook installation, Ollama connectivity, log viewing, and status monitoring.

**Target:** macOS 14+ (Sonoma), Apple Silicon (M-series). SwiftUI. No Electron, no web views.

**Distribution:** Direct DMG download (no App Store). Sparkle 2 for auto-updates.

**Name:** HookQA  
**Bundle ID:** `co.uk.bitmoor.hookqa`  
**Menubar icon:** Small shield or checkmark glyph (SF Symbols: `checkmark.shield` or `checkmark.circle`)

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   HookQA.app                    │
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ Settings │  │  Ollama  │  │    Hook      │  │
│  │ Manager  │  │ Client   │  │  Installer   │  │
│  └────┬─────┘  └────┬─────┘  └──────┬───────┘  │
│       │              │               │          │
│       ▼              ▼               ▼          │
│  hookqa.json      /api/tags    hookqa-hook.ts   │
│  (~/.claude/      /api/chat    (~/.claude/       │
│   hooks/)                       hooks/)          │
│                                                 │
│  ┌──────────┐  ┌──────────────────────────────┐ │
│  │   Log    │  │     Status Monitor           │ │
│  │ Viewer   │  │  (Ollama health, last QA)    │ │
│  └──────────┘  └──────────────────────────────┘ │
└─────────────────────────────────────────────────┘

         ┌──────────────┐
         │  Claude Code  │
         │  (Stop hook)  │
         │       ↓       │
         │ Reads config  │
         │ from JSON     │
         │       ↓       │
         │ Calls Ollama  │
         │       ↓       │
         │ Pass/Fail     │
         └──────────────┘
```

### Key design principle

The app writes configuration. The hook script reads it. They share a single JSON config file at `~/.claude/hooks/hookqa.json`. The hook script is a standalone Bun/TypeScript file that Claude Code executes — the app is not in the runtime path during QA evaluation.

---

## Data Model

### Config file: `~/.claude/hooks/hookqa.json`

```json
{
  "version": 1,
  "connection": {
    "ollamaUrl": "http://localhost:11434",
    "model": "qwen3:30b-coder",
    "apiKey": null,
    "timeout": 120
  },
  "behaviour": {
    "enabled": true,
    "blockOnWarnings": false,
    "maxDiffLines": 500,
    "minDiffLines": 5,
    "maxRetries": 1,
    "temperature": 0.1
  },
  "review": {
    "weights": {
      "correctness": 10,
      "completeness": 8,
      "specAdherence": 6,
      "codeQuality": 4
    },
    "customInstructions": ""
  },
  "logging": {
    "enabled": true,
    "logFile": "~/.claude/hooks/hookqa.log"
  }
}
```

### Project overrides: `.claude/hookqa.json` (per-project)

Same schema as the `review` and `behaviour` sections. Merges over global config when the hook detects a project-level file. Example:

```json
{
  "behaviour": {
    "blockOnWarnings": true,
    "maxDiffLines": 800
  },
  "review": {
    "weights": {
      "completeness": 10
    },
    "customInstructions": "This project uses Bun — flag any Node-specific APIs. Pay close attention to Prisma schema changes."
  }
}
```

### Log entries: `~/.claude/hooks/hookqa.log`

JSONL format, one entry per line:

```json
{"timestamp":"2026-04-01T10:30:00Z","project":"ss-stores","model":"qwen3:30b-coder","verdict":"FAIL","findings":3,"criticals":1,"warnings":2,"summary":"Missing error handling in checkout flow","durationMs":45200}
```

---

## UI Design

### Menubar

- **Icon:** `checkmark.shield` (SF Symbols), coloured by status:
  - Green: enabled + Ollama reachable
  - Grey: disabled
  - Red: enabled but Ollama unreachable
  - Amber: enabled, last QA had criticals
- **Click:** Opens popover panel (not a separate window — same pattern as ollmlx)

### Popover Panel

Fixed width 380pt. Five sections accessed via a segmented control or sidebar tabs at the top.

#### Status Bar (always visible at top of popover)

Compact single-line bar showing:
- Status dot (green/grey/red/amber)
- Current model name (monospaced, truncated)
- Master enable/disable toggle (right-aligned)

#### Tab 1: Connection

- **Ollama Endpoint** — text field, default `http://localhost:11434`
- **Refresh** button — re-fetches `/api/tags`
- **Model Picker** — list of models fetched from Ollama, showing:
  - Model name (monospaced)
  - Parameter size + quantization (e.g. "30B • Q4_K_M")
  - File size
  - Selected state (highlight + checkmark)
- **Manual model entry** — text field fallback if Ollama is unreachable
- **API Key** — optional secure text field for cloud Ollama endpoints. Stored in macOS Keychain as the primary store. On config save, the app reads from Keychain and writes the key into `hookqa.json` so the hook script can access it without Keychain access.
- **Test Connection** button — sends a minimal chat request, reports latency or error

#### Tab 2: Behaviour

- **Preset buttons** — Strict / Balanced / Light (applies a preset to all fields below)
- **Block on Warnings** — toggle. When on, warnings (not just criticals) block Claude.
- **Max Diff Lines** — stepper or slider, 100–2000, step 100
- **Min Diff Lines** — stepper or slider, 0–50, step 5. Diffs below this are skipped.
- **Max Retries** — stepper, 1–3. How many times Claude can retry before the hook lets it stop.
- **Timeout** — stepper or slider, 30–300s, step 10
- **Temperature** — slider, 0.0–1.0, step 0.05

#### Tab 3: Review Criteria

- **Correctness** — slider 0–10 + description
- **Completeness** — slider 0–10 + description
- **Spec Adherence** — slider 0–10 + description
- **Code Quality** — slider 0–10 + description
- **Custom Instructions** — multi-line text editor. Freeform text appended to the QA prompt.

Each slider shows the current value and has a short description below explaining what it covers.

#### Tab 4: Logs

- **Log list** — scrollable list of recent QA evaluations from the JSONL log file, newest first. Each row shows:
  - Timestamp (relative, e.g. "2 min ago")
  - Project name
  - Verdict badge (PASS green, FAIL red, ERROR grey, SKIPPED muted)
  - Finding count
  - Duration
- **Tap a row** → expands to show the full summary text
- **Clear logs** button (with confirmation)
- **Open log file in Finder** button
- File watcher on the log file for live updates (FSEvents)

#### Tab 5: Hook Management

- **Installation status** — shows whether:
  - Hook script exists at `~/.claude/hooks/hookqa-hook.ts`
  - Hook is registered in `~/.claude/settings.json`
  - Bun is available on PATH
- **Install Hook** button — writes the hook script + updates settings.json (see Hook Installer below)
- **Uninstall Hook** button — removes the hook script + removes the Stop hook entry from settings.json
- **Reinstall / Update** button — overwrites the hook script with the latest version bundled in the app
- **View Hook Script** — opens the script in the default editor
- **Hook script version** — the app bundles a version of `hookqa-hook.ts` and tracks whether the installed version matches

---

## Core Services

### 1. Settings Manager

Reads and writes `~/.claude/hooks/hookqa.json`.

- Loads on app launch, writes on every change (debounced 500ms)
- Creates the directory + file if they don't exist
- Validates schema on read, migrates if `version` field is outdated
- All SwiftUI views bind to a shared `@Observable` settings object

### 2. Ollama Client

Communicates with the Ollama API.

**Endpoints used:**
- `GET /api/tags` — list available models (for the model picker)
- `POST /api/chat` — test connection (minimal prompt)
- `GET /api/show` — get model details (parameter size, quant, family)

**Behaviour:**
- Polls `/api/tags` on app launch and when endpoint changes
- Connection status tracked as an enum: `.connected(modelCount)`, `.unreachable`, `.checking`
- API key (if set) sent as `Authorization: Bearer <key>` header
- All requests have a 5s timeout for health checks, configurable timeout for test chat
- Uses `async/await` with `URLSession`

### 3. Hook Installer

Manages the Claude Code hook lifecycle.

**Hook script:**
- The app bundles `hookqa-hook.ts` in its Resources
- On install, copies it to `~/.claude/hooks/hookqa-hook.ts` and sets executable permission
- The bundled script reads `~/.claude/hooks/hookqa.json` for all settings (not env vars)

**Settings.json management:**
- Reads `~/.claude/settings.json` (creating it if absent)
- Parses as JSON, preserving all existing keys
- Adds/removes the Stop hook entry:
  ```json
  {
    "hooks": {
      "Stop": [
        {
          "hooks": [
            {
              "type": "command",
              "command": "bun ~/.claude/hooks/hookqa-hook.ts",
              "timeout": 120
            }
          ]
        }
      ]
    }
  }
  ```
- On uninstall, removes only the HookQA entry from the Stop array — does not touch other hooks
- The timeout value in settings.json is kept in sync with the config's timeout setting

**Version tracking:**
- The app writes a version comment on the second line of the hook script (line 1 is the shebang `#!/usr/bin/env bun`, line 2 is `// hookqa-hook v1.0.0`)
- On launch, compares installed version vs bundled version
- Shows "Update Available" badge on the Hook Management tab if mismatched

**Bun detection:**
- Checks for `bun` on PATH using `Process` + `which bun`
- If not found, shows a warning with a link to bun.sh

### 4. Log Viewer

Reads and displays `~/.claude/hooks/hookqa.log`.

- Parses JSONL, newest first
- FSEvents file watcher for live updates
- Capped display at 200 entries (older entries still in file)
- Each entry parsed into a `HookQALogEntry` struct
- Clear button truncates the file (with confirmation alert)

### 5. Status Monitor

Runs on a timer (every 30s) to update the menubar icon colour.

- Checks Ollama reachability (HEAD request to `/api/tags`)
- Reads the last log entry to determine last QA result
- Updates the menubar icon colour accordingly
- Fires on app launch + on config changes + on timer

---

## Updated Hook Script

The bundled `hookqa-hook.ts` must be updated from the current `qa-evaluator.ts` to:

1. **Read `~/.claude/hooks/hookqa.json`** as the primary config source, falling back to env vars, falling back to defaults
2. **Use weights from config** to dynamically build the QA prompt (e.g. "Pay PRIMARY attention to correctness (10/10)…")
3. **Support `maxRetries`** — track retry count via a temp file (`/tmp/hookqa-{session_id}-retries`). Increment on each block. When count >= maxRetries, exit 0 regardless.
4. **Support `blockOnWarnings`** — when true, any warning-severity finding also triggers exit 2
5. **Support `minDiffLines`** — if the diff is shorter than this, skip QA entirely (exit 0)
6. **Support `apiKey`** — read from config (the app writes it there from Keychain on save) and send as `Authorization: Bearer` header. NOTE: The API key in the JSON file should be the actual key value — the app reads from Keychain and writes to the config file so the hook doesn't need Keychain access.
7. **Support `customInstructions`** — append to the QA prompt
8. **Read project-level overrides** — check for `.claude/hookqa.json` in the current working directory and deep-merge over global config
9. **Write JSONL log entries** with project name (derived from git remote or directory name), model, verdict, finding counts, summary, and duration
10. **Clean up temp retry file** on exit 0 (successful stop)

---

## App Lifecycle

### First Launch
1. Create `~/.claude/hooks/` directory if missing
2. Write default `hookqa.json`
3. Prompt user: "Install the HookQA hook for Claude Code?" → runs Hook Installer
4. Check for Bun, warn if missing
5. Fetch Ollama models

### Normal Launch
1. Load config from JSON
2. Check Ollama connectivity
3. Check hook installation status
4. Start status monitor timer
5. Start log file watcher

### Quit
1. No cleanup needed — the hook runs independently of the app

---

## Build & Distribution

- **Xcode project**, Swift 6, SwiftUI
- **macOS 14+** deployment target
- **Sparkle 2** for auto-updates (appcast URL TBD, hosted on bitmoor.co.uk or GitHub Releases)
- **DMG** distribution via `create-dmg` or similar
- **Code signing:** Developer ID (or unsigned for personal use initially)
- **Bundle ID:** `co.uk.bitmoor.hookqa`
- **Launch at Login:** LSUIElement (menubar-only app, no dock icon). Optional "Launch at Login" toggle in settings using `SMAppService`.

---

## File Tree

```
hookqa/
├── HookQA.xcodeproj
├── HookQA/
│   ├── App/
│   │   └── HookQAApp.swift                # @main, NSStatusItem, popover setup
│   ├── Models/
│   │   ├── HookQAConfig.swift             # Codable config model
│   │   ├── HookQALogEntry.swift           # Codable log entry model
│   │   ├── OllamaModel.swift              # Codable model from /api/tags
│   │   └── ConnectionStatus.swift         # Enum: connected/unreachable/checking
│   ├── Services/
│   │   ├── SettingsManager.swift           # Read/write hookqa.json, @Observable
│   │   ├── OllamaClient.swift             # URLSession-based Ollama API client
│   │   ├── HookInstaller.swift            # Install/uninstall/update hook + settings.json
│   │   ├── LogWatcher.swift               # FSEvents file watcher + JSONL parser
│   │   └── StatusMonitor.swift            # Timer-based status polling
│   ├── Views/
│   │   ├── MenuBarView.swift              # Popover root with tab navigation
│   │   ├── StatusBarView.swift            # Top status bar (dot + model + toggle)
│   │   ├── ConnectionTab.swift            # Endpoint, model picker, test button
│   │   ├── BehaviourTab.swift             # Presets, toggles, sliders
│   │   ├── ReviewTab.swift                # Weight sliders, custom instructions
│   │   ├── LogsTab.swift                  # Log list with expandable rows
│   │   └── HookTab.swift                  # Install/uninstall/status
│   ├── Resources/
│   │   └── hookqa-hook.ts                 # Bundled hook script
│   └── Utilities/
│       ├── KeychainHelper.swift           # Keychain read/write for API key
│       └── ShellHelper.swift              # Run shell commands (which bun, chmod, etc.)
├── Sparkle/                               # Sparkle 2 framework
└── README.md
```

---

## Implementation Phases

### Phase 1: Scaffold & Core Services
- Xcode project setup (menubar app, LSUIElement, SwiftUI lifecycle)
- `HookQAConfig` model + `SettingsManager` (read/write JSON)
- `OllamaClient` (fetch models, test connection)
- Basic popover with status bar and tab navigation
- Connection tab (endpoint input, model list, test button)

### Phase 2: Configuration UI
- Behaviour tab (presets, all toggles/sliders)
- Review tab (weight sliders, custom instructions editor)
- All changes write to `hookqa.json` via SettingsManager (debounced)

### Phase 3: Hook Management
- Bundle `hookqa-hook.ts` in Resources
- `HookInstaller` service (install/uninstall/update/status check)
- Hook Management tab UI
- Bun detection
- `settings.json` read/merge/write logic

### Phase 4: Updated Hook Script
- Rewrite `hookqa-hook.ts` to read `hookqa.json` (with env var + default fallback chain)
- Dynamic prompt building from weights
- `maxRetries` support via temp file
- `blockOnWarnings`, `minDiffLines`, `apiKey`, `customInstructions` support
- Project-level override merging (`.claude/hookqa.json`)
- JSONL structured logging

### Phase 5: Logs & Status
- `LogWatcher` with FSEvents
- Logs tab UI (list, expand, clear)
- `StatusMonitor` (timer-based polling, menubar icon colour)

### Phase 6: Distribution
- Sparkle 2 integration
- DMG build script
- Auto-update appcast
- Launch at Login toggle (SMAppService)
- README + first-run onboarding

---

## Edge Cases & Notes

- **Multiple Claude Code sessions:** The hook runs per-session. The retry temp file includes the session ID to avoid cross-session interference.
- **Concurrent settings writes:** The app debounces writes. The hook only reads the config — no write contention.
- **Ollama model not pulled:** If the selected model isn't available locally, Ollama returns an error. The hook handles this gracefully (exit 0, non-blocking).
- **Large diffs:** Truncated to `maxDiffLines`. The hook should log when truncation occurs so the user knows context was lost.
- **No git repo:** If the hook runs outside a git repository (no diff available), it exits 0 silently.
- **settings.json doesn't exist:** Hook Installer creates it with just the hooks key. Does not overwrite existing content.
- **settings.json has other hooks:** Hook Installer appends to the existing Stop array, or creates it. On uninstall, removes only the HookQA entry (matched by command string containing `hookqa`).
- **API key security:** Stored in macOS Keychain by the app. Written to `hookqa.json` so the hook can read it without Keychain access (the hook runs as a subprocess of Claude Code, not as the app). This is acceptable because the config file is in the user's home directory with standard permissions. If the user is uncomfortable with this, they can leave the key blank in the app and set it via env var instead.
- **Hook script updates:** When the app updates via Sparkle, the bundled hook script may have a newer version. The Hook Management tab shows a badge and offers a one-click update.
