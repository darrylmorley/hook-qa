# HookQA — Phase 1 Kick-off Prompt

Copy the below into Claude Code to start Phase 1.

---

Read the spec at `HOOKQA_SPEC.md` thoroughly before doing anything. This is the full specification for HookQA — a macOS menubar app that manages a Claude Code Stop hook for automated QA evaluation via Ollama.

You are implementing **Phase 1: Scaffold & Core Services**. Here is what needs to be built:

## Deliverables

1. **Xcode project setup**
   - Create a new SwiftUI macOS app called HookQA
   - Bundle ID: `co.uk.bitmoor.hookqa`
   - Deployment target: macOS 14+
   - Swift 6
   - LSUIElement = YES (menubar-only, no dock icon)
   - Set up the NSStatusItem with `checkmark.shield` SF Symbol as the menubar icon
   - Popover-based UI (not a window) — same pattern as a standard macOS menubar app

2. **HookQAConfig model** (`Models/HookQAConfig.swift`)
   - Codable struct matching the `hookqa.json` schema from the spec exactly
   - Nested structs: `ConnectionConfig`, `BehaviourConfig`, `ReviewConfig`, `WeightsConfig`, `LoggingConfig`
   - Default values matching the spec defaults
   - Top-level `version: Int` field (default 1) for future config migration

3. **OllamaModel** (`Models/OllamaModel.swift`)
   - Codable struct for the response from Ollama's `/api/tags` endpoint
   - Fields: name, size, modified_at, details (parameter_size, quantization_level, family)

4. **ConnectionStatus** (`Models/ConnectionStatus.swift`)
   - Enum: `.connected(Int)` (model count), `.unreachable`, `.checking`

5. **SettingsManager** (`Services/SettingsManager.swift`)
   - `@Observable` class
   - Reads/writes `~/.claude/hooks/hookqa.json`
   - Creates the directory and file if they don't exist on first access
   - Loads config on init
   - Saves on change, debounced 500ms
   - Validates and handles missing/malformed config gracefully (falls back to defaults)

6. **OllamaClient** (`Services/OllamaClient.swift`)
   - `async/await` with `URLSession`
   - `fetchModels()` → hits `GET /api/tags`, returns `[OllamaModel]`
   - `testConnection(model:)` → sends a minimal `POST /api/chat` request, returns response time or error
   - API key support via `Authorization: Bearer` header (read from config)
   - 5s timeout for health checks

7. **Popover UI**
   - `MenuBarView.swift` — root view with a segmented control or tab bar at the top for navigation between tabs. Only the Connection tab needs to be functional in this phase — the other tabs can be placeholder views with the tab name.
   - `StatusBarView.swift` — compact bar always visible at the top showing: status dot (coloured by connection state), current model name in monospaced font (truncated if long), master enable/disable toggle on the right
   - `ConnectionTab.swift` — Ollama endpoint text field, refresh button, scrollable model list (fetched from Ollama) with model name, parameter size, quant level, file size, and selected state. Manual model name text field as fallback. Test Connection button showing latency result.

8. **ShellHelper** (`Utilities/ShellHelper.swift`)
   - Simple wrapper around `Process` for running shell commands
   - Used later for `which bun`, `chmod`, etc. — just set up the utility now

## File structure

Follow the file tree from the spec:

```
HookQA/
├── App/
│   └── HookQAApp.swift
├── Models/
│   ├── HookQAConfig.swift
│   ├── HookQALogEntry.swift (stub — just the struct, used later)
│   ├── OllamaModel.swift
│   └── ConnectionStatus.swift
├── Services/
│   ├── SettingsManager.swift
│   └── OllamaClient.swift
├── Views/
│   ├── MenuBarView.swift
│   ├── StatusBarView.swift
│   └── ConnectionTab.swift
└── Utilities/
    └── ShellHelper.swift
```

## Rules

- Use Swift 6 and SwiftUI throughout
- Use `@Observable` (Observation framework), not `ObservableObject`/`@Published`
- The popover should be 380pt wide
- All network calls must be async/await
- Handle errors gracefully — never crash if Ollama is offline or config is malformed
- Write clean, readable Swift — small focused functions, early returns, explicit error handling
- Do not add Sparkle, DMG scripts, or anything from Phases 2–6 yet
- Test that the app builds and runs — the menubar icon should appear, the popover should open on click, and if Ollama is running locally it should list the available models
