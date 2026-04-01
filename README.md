# HookQA

HookQA is a macOS menubar app that adds automated QA review to [Claude Code](https://claude.ai/code). It installs a Claude Code Stop hook that sends code changes to an [Ollama](https://ollama.com) model — local or cloud — for review. If the model finds critical issues, Claude Code is blocked from stopping and receives findings as actionable feedback.

## Installation

1. Download the latest `HookQA-x.x.dmg` from the [Releases](https://github.com/bitmoor/hook-qa/releases) page.
2. Open the DMG and drag **HookQA.app** to your Applications folder.
3. Launch HookQA — it appears as a shield icon in your menu bar.
4. On first launch the onboarding wizard walks you through connecting to Ollama and installing the hook.

> **Requirements:** macOS 14 (Sonoma) or later, [Bun](https://bun.sh), [Ollama](https://ollama.com) with at least one model pulled or an Ollama cloud account.

## First Launch Walkthrough

The four-step onboarding wizard guides you through:

1. **Welcome** — overview of what HookQA does.
2. **Connect** — enter your Ollama endpoint (default: `http://localhost:11434`), choose a local or cloud model, and optionally add an API key.
3. **Install** — installs `~/.claude/hooks/hookqa-hook.ts` and registers the Stop hook in Claude Code's `settings.json`.
4. **Done** — you're ready. The shield icon in the menu bar shows your connection status.

You can skip onboarding at any time; settings are accessible via the menubar popover.

## How It Works

```
Claude Code finishes a task
        |
        v
hookqa-hook.ts (Stop hook, runs via Bun)
        |
        +-- Reads config from ~/.claude/hooks/hookqa.json
        +-- Collects git diff (staged + unstaged)
        +-- Skips if diff < minDiffLines (no API call)
        +-- Sends diff + QA prompt to Ollama (local or cloud)
        |
        v
Ollama reviews the changes
        |
        +-- PASS    -> hook exits 0, Claude stops normally
        +-- FAIL    -> hook exits 2 with findings on stderr
        |             Claude sees feedback and continues working
        +-- SKIPPED -> diff below minDiffLines, exits 0
        +-- ERROR   -> infrastructure error, exits 0 (never blocks)
```

The hook script reads `hookqa.json` for all settings — the app is not in the runtime path during QA evaluation.

## Local vs Cloud Models

HookQA supports both local Ollama models and [Ollama cloud models](https://docs.ollama.com/cloud).

**Local models** run on your machine via Ollama and hit `http://localhost:11434`. They're free and fast but limited by your hardware.

**Cloud models** are routed to `https://ollama.com/api/chat` per the [Ollama cloud docs](https://docs.ollama.com/cloud). They appear in the Connection tab with a cloud icon and use the `:cloud` suffix (e.g. `deepseek-v3.2:cloud`). Cloud models require:

- An Ollama account ([ollama.com](https://ollama.com))
- Sign in via `ollama signin`
- An API key from [ollama.com/settings/keys](https://ollama.com/settings/keys), entered in the Connection tab

### Model Comparison

Results from testing with the same intentionally buggy TypeScript file (4-5 planted issues):

| Model | Time | Findings | Notes |
|-------|------|----------|-------|
| `deepseek-v3.2:cloud` | 60-87s | 5/5 | Most thorough, caught everything |
| `minimax-m2:cloud` | 20s | 4/5 | Good balance of speed and quality |
| `qwen3-next:80b:cloud` | 13s | 2/5 | Fast but missed critical issues |
| `glm-4.6:cloud` | ~9s | — | Fastest connection, untested for QA |

Choose based on your preference for speed vs thoroughness. You can change models any time in the Connection tab.

## Configuration

Settings are stored in `~/.claude/hooks/hookqa.json` and managed through the app's popover UI.

### Connection

| Setting | Description | Default |
|---|---|---|
| `connection.ollamaUrl` | Ollama HTTP endpoint (local models only) | `http://localhost:11434` |
| `connection.model` | Model name for QA reviews | — |
| `connection.apiKey` | API key for Ollama cloud models | `null` |
| `connection.timeout` | Request timeout in seconds | `120` |

Cloud models (names ending in `:cloud`) are automatically routed to `https://ollama.com` with the API key as a Bearer token.

### Behaviour

| Setting | Description | Default |
|---|---|---|
| `behaviour.enabled` | Master enable/disable toggle | `true` |
| `behaviour.blockOnWarnings` | Block on warnings, not just criticals | `false` |
| `behaviour.maxDiffLines` | Max diff lines sent to model (100-2000) | `500` |
| `behaviour.minDiffLines` | Skip QA below this threshold (0-50) | `5` |
| `behaviour.maxRetries` | Retries before letting Claude stop (1-3) | `1` |
| `behaviour.temperature` | Model temperature (0.0-1.0) | `0.1` |

Three presets are available: **Strict**, **Balanced**, and **Light**.

### Review Weights

Each criterion is weighted 0-10. Higher weights get more attention in the QA prompt:

| Weight | Description | Default |
|---|---|---|
| `review.weights.correctness` | Bugs, logic errors, edge cases | `10` |
| `review.weights.completeness` | Stubs, TODOs, half-finished features | `8` |
| `review.weights.specAdherence` | Does code match what was asked? | `6` |
| `review.weights.codeQuality` | Code smells, duplication, nesting | `4` |

Custom instructions can be appended to the QA prompt via `review.customInstructions`. For example:

```
Only flag issues you are highly confident about. Focus on application logic, not infrastructure patterns.
```

### Project-Level Overrides

Override `behaviour` and `review` settings per project by creating `.claude/hookqa.json` in your project root. Values deep-merge over the global config:

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
    "customInstructions": "This project uses Bun — flag any Node-specific APIs."
  }
}
```

## File Locations

| File | Purpose |
|---|---|
| `~/.claude/hooks/hookqa.json` | Global config (app writes, hook reads) |
| `~/.claude/hooks/hookqa-hook.ts` | Hook script (installed by app) |
| `~/.claude/hooks/hookqa.log` | QA evaluation log |
| `~/.claude/settings.json` | Claude Code settings (hook registration) |
| `.claude/hookqa.json` | Per-project overrides (optional) |

## Menubar Icon Status

The shield icon colour indicates current state:

- **Green** — enabled, Ollama reachable
- **Grey** — QA disabled
- **Red** — enabled but Ollama unreachable
- **Amber** — enabled, last QA evaluation failed

## Building from Source

**Requirements:**
- Xcode 16+
- macOS 14 SDK
- Swift 6
- [create-dmg](https://github.com/create-dmg/create-dmg) (`brew install create-dmg`) for DMG builds

```bash
# Clone
git clone https://github.com/bitmoor/hook-qa.git
cd hook-qa

# Open in Xcode
open HookQA/HookQA.xcodeproj

# Or build from the command line (Debug)
cd HookQA
xcodebuild build -scheme HookQA -configuration Debug

# Build a distributable DMG (Release)
cd ..
./scripts/build-dmg.sh
```

> The app is **not sandboxed** — it needs filesystem access to `~/.claude/` and shell access to run `bun` and `git` commands.

## Auto-Updates

HookQA uses [Sparkle 2](https://sparkle-project.org) for automatic updates. Updates are checked on launch; you can also trigger a manual check from the Hook tab.

## License

Copyright 2026 Bitmoor Ltd. All rights reserved.
