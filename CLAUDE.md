# CLAUDE.md — HookQA

## Project

HookQA is a macOS menubar app (SwiftUI) that manages a Claude Code Stop hook for automated QA evaluation via Ollama. See `docs/HOOKQA_SPEC.md` for the full specification.

## Tech Stack

- Swift 6, SwiftUI, macOS 14+
- Xcode project (not Swift Package), Sparkle 2 via SPM for auto-updates
- LSUIElement menubar app (no dock icon)
- Bun/TypeScript for the hook script (`hookqa-hook.ts`)
- Ollama API for QA model inference

## Project Structure

```
HookQA/
├── HookQA.xcodeproj/
├── HookQA/
│   ├── App/
│   │   └── HookQAApp.swift           # @main, AppDelegate, NSStatusItem, popover
│   ├── Models/
│   │   ├── HookQAConfig.swift         # Codable config matching hookqa.json
│   │   ├── HookQALogEntry.swift       # Codable log entry with Verdict enum
│   │   ├── OllamaModel.swift          # Ollama /api/tags response model
│   │   └── ConnectionStatus.swift     # .connected/.unreachable/.checking enum
│   ├── Services/
│   │   ├── SettingsManager.swift      # @Observable, reads/writes hookqa.json
│   │   ├── OllamaClient.swift         # Actor, fetchModels/testConnection
│   │   ├── HookInstaller.swift        # @Observable, install/uninstall/update hook
│   │   ├── LogWatcher.swift           # @Observable, DispatchSource file watcher
│   │   └── StatusMonitor.swift        # @Observable, 30s polling, menubar status
│   ├── Views/
│   │   ├── MenuBarView.swift          # Popover root, tab navigation, onboarding gate
│   │   ├── StatusBarView.swift        # Status dot, model name, enable toggle
│   │   ├── ConnectionTab.swift        # Endpoint, model picker, API key, test
│   │   ├── BehaviourTab.swift         # Presets, sliders, toggles
│   │   ├── ReviewTab.swift            # Weight sliders, custom instructions
│   │   ├── LogsTab.swift              # Log list with expandable entries
│   │   ├── HookTab.swift              # Install/uninstall, version, launch at login
│   │   └── OnboardingView.swift       # 4-step first-run wizard
│   ├── Resources/
│   │   └── hookqa-hook.ts             # Bundled hook script (copied on install)
│   └── Utilities/
│       ├── KeychainHelper.swift       # Keychain read/write for API key
│       └── ShellHelper.swift          # Process wrapper for shell commands
├── scripts/
│   └── build-dmg.sh                   # Signed + notarized release DMG builder
└── docs/
    ├── HOOKQA_SPEC.md                 # Full product specification
    └── build-prompts/                 # Phase prompts used during initial build
```

## Tracking

Todos, enhancements, and bugs are tracked as [GitHub Issues](https://github.com/darrylmorley/hook-qa/issues).

## Conventions

- Use `@Observable` (Observation framework), NOT `ObservableObject`/`@Published`
- Small focused functions, early returns, explicit error handling
- async/await for all network and file I/O
- Handle errors gracefully — never crash if Ollama is offline or config is malformed
- Use `JSONSerialization` (not Codable) when reading/writing `~/.claude/settings.json` to preserve arbitrary keys
- Use `Codable` for `hookqa.json` since we own the full schema

## File Locations (Runtime)

- Config: `~/.claude/hooks/hookqa.json`
- Hook script: `~/.claude/hooks/hookqa-hook.ts`
- Log file: `~/.claude/hooks/hookqa.log`
- Claude Code settings: `~/.claude/settings.json`
- Project overrides: `.claude/hookqa.json` (in project root)

## Key Design Rules

- The app writes config. The hook reads config. They never run simultaneously on the same file.
- The hook script must be standalone — no npm dependencies, Bun built-ins only.
- settings.json manipulation must preserve ALL existing content. Never overwrite or lose other hooks/settings.
- The hook must never block Claude Code if Ollama is offline — exit 0 on any infrastructure error.
- API key lives in macOS Keychain (app-side) but gets written into hookqa.json so the hook can read it.

## Building

```bash
cd HookQA && xcodebuild build -scheme HookQA -configuration Debug
```

For a signed + notarized release DMG:

```bash
./scripts/build-dmg.sh          # requires create-dmg + Developer ID cert
SKIP_NOTARIZE=1 ./scripts/build-dmg.sh   # signed but not notarized
```

The build script auto-detects the Developer ID signing identity, re-signs all nested binaries (Sparkle XPC services, Updater.app), and submits to Apple's notary service. Notarization credentials are stored in the keychain under the profile `hookqa-notary`.

## Do Not

- Do not use ObservableObject or @Published — use @Observable only
- Do not use CocoaPods or Carthage — SPM only for dependencies
- Do not sandbox the app — it needs filesystem and shell access
- Do not add dependencies to the hook script — Bun built-ins only
- Do not hardcode paths to any specific user's home directory
