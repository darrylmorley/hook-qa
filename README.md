<div align="center">

# HookQA

**Automated QA review for Claude Code, powered by Ollama**

[![macOS](https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Ollama](https://img.shields.io/badge/Ollama-Local%20%26%20Cloud-1a1a2e?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PGNpcmNsZSBjeD0iMTIiIGN5PSIxMiIgcj0iMTAiIGZpbGw9IiNmZmYiLz48L3N2Zz4=)](https://ollama.com)
[![License](https://img.shields.io/badge/License-Proprietary-blue)](LICENSE)

A native macOS menubar app that installs a [Claude Code](https://claude.ai/code) Stop hook to automatically review your code changes using local or cloud AI models. When the reviewer finds critical issues, Claude Code is blocked and receives actionable feedback.

[Getting Started](#installation) · [How It Works](#how-it-works) · [Configuration](#configuration) · [Building](#building-from-source)

</div>

---

## Highlights

- **Zero friction** — lives in your menubar, installs the hook in one click
- **Local & cloud models** — use your own GPU or [Ollama cloud models](https://docs.ollama.com/cloud)
- **Smart skipping** — no API calls when there's no meaningful code diff
- **Non-blocking** — infrastructure errors never block Claude Code
- **Per-project overrides** — tune QA strictness per repository
- **Live status** — menubar icon shows connection state and spins during review

## Installation

1. Download the latest `HookQA-x.x.dmg` from the [Releases](https://github.com/bitmoor/hook-qa/releases) page
2. Drag **HookQA.app** to your Applications folder
3. Launch — it appears as a shield icon in your menu bar
4. Follow the onboarding wizard to connect and install the hook

### Requirements

| Dependency | Purpose |
|---|---|
| macOS 14+ (Sonoma) | Minimum OS version |
| [Bun](https://bun.sh) | Runs the hook script |
| [Ollama](https://ollama.com) | Local models, or cloud account |

## How It Works

```
Claude Code finishes a task
        │
        ▼
hookqa-hook.ts (Stop hook, runs via Bun)
        │
        ├── Reads config from ~/.claude/hooks/hookqa.json
        ├── Collects git diff (staged + unstaged)
        ├── Skips if diff < minDiffLines (no API call)
        ├── Sends diff + QA prompt to Ollama (local or cloud)
        │
        ▼
   ┌─────────┐
   │  Ollama  │
   └────┬────┘
        │
        ├── PASS    → exits 0, Claude stops normally
        ├── FAIL    → exits 2, Claude sees findings and keeps working
        ├── SKIPPED → diff too small, exits 0
        └── ERROR   → infra error, exits 0 (never blocks)
```

The hook script reads `hookqa.json` for all settings — the app is not in the runtime path during QA evaluation.

### Exit Codes

| Code | Meaning | Effect |
|:---:|---|---|
| `0` | Pass, skipped, or infrastructure error | Claude Code stops normally |
| `2` | Fail — critical issues found | Claude Code is blocked and receives findings |

The hook always exits `0` on infrastructure errors (Ollama offline, config missing, no git repo) so it never blocks Claude Code due to tooling problems.

## Local vs Cloud Models

| | Local | Cloud |
|---|---|---|
| **Endpoint** | `localhost:11434` | `ollama.com` |
| **Cost** | Free | Per Ollama account |
| **Speed** | Depends on hardware | 3–90s depending on model |
| **Setup** | `ollama pull <model>` | `ollama signin` + API key |

Cloud models appear in the Connection tab with a cloud icon and use the `:cloud` suffix (e.g. `deepseek-v3.2:cloud`). They require an API key from [ollama.com/settings/keys](https://ollama.com/settings/keys).

### Model Benchmarks

Tested against the same intentionally buggy TypeScript file with 5 planted issues:

| Model | Response Time | Issues Found | Verdict |
|:------|:---:|:---:|:---|
| `deepseek-v3.2:cloud` | 60–87s | 5/5 | Most thorough |
| `minimax-m2:cloud` | 20s | 4/5 | Best balance |
| `qwen3-next:80b:cloud` | 13s | 2/5 | Fast, less thorough |
| `nemotron-3-nano:30b:cloud` | 3s | Hallucinated | Too fast, unreliable |

> Choose based on your tolerance for wait time vs missed issues. You can change models any time in the Connection tab.

## Configuration

All settings are managed through the menubar popover and stored in `~/.claude/hooks/hookqa.json`.

### Connection

| Setting | Description | Default |
|---|---|---|
| `connection.ollamaUrl` | Ollama endpoint (local models) | `http://localhost:11434` |
| `connection.model` | Model name for QA reviews | — |
| `connection.apiKey` | API key for cloud models | `null` |
| `connection.timeout` | Request timeout in seconds | `120` |

### Behaviour

| Setting | Description | Default |
|---|---|---|
| `behaviour.enabled` | Master enable/disable | `true` |
| `behaviour.blockOnWarnings` | Block on warnings, not just criticals | `false` |
| `behaviour.maxDiffLines` | Max diff lines sent to model | `500` |
| `behaviour.minDiffLines` | Skip QA below this threshold | `5` |
| `behaviour.maxRetries` | Retries before letting Claude stop | `1` |
| `behaviour.temperature` | Model temperature | `0.1` |

Three presets are available: **Strict**, **Balanced**, and **Light**.

### Review Weights

Each criterion is weighted 0–10. Higher weights get more attention in the QA prompt:

| Criterion | Focus | Default |
|---|---|:---:|
| Correctness | Bugs, logic errors, edge cases | `10` |
| Completeness | Stubs, TODOs, half-finished features | `8` |
| Spec Adherence | Does code match what was asked? | `6` |
| Code Quality | Code smells, duplication, nesting | `4` |

Custom instructions can be added via `review.customInstructions`:

```
Only flag issues you are highly confident about.
Focus on application logic, not infrastructure patterns.
```

### Project-Level Overrides

Create `.claude/hookqa.json` in your project root to override per-project:

```json
{
  "behaviour": {
    "blockOnWarnings": true,
    "maxDiffLines": 800
  },
  "review": {
    "weights": { "completeness": 10 },
    "customInstructions": "This project uses Bun — flag any Node-specific APIs."
  }
}
```

## Menubar Status

| Icon | Meaning |
|:---:|---|
| 🟢 Shield | Enabled, Ollama reachable |
| ⚪ Shield | QA disabled |
| 🔴 Shield | Enabled, Ollama unreachable |
| 🟠 Shield | Last QA evaluation failed |
| 🔄 Spinning | QA review in progress |

## File Locations

```
~/.claude/
├── hooks/
│   ├── hookqa.json          # Global config
│   ├── hookqa-hook.ts       # Hook script (installed by app)
│   └── hookqa.log           # QA evaluation log
└── settings.json            # Claude Code settings (hook registration)

<your-project>/
└── .claude/
    └── hookqa.json           # Per-project overrides (optional)
```

## Building from Source

**Requirements:** Xcode 16+, macOS 14 SDK, Swift 6

```bash
git clone https://github.com/bitmoor/hook-qa.git
cd hook-qa/HookQA
xcodebuild build -scheme HookQA -configuration Debug
```

### Release DMG (signed + notarized)

Requires [create-dmg](https://github.com/create-dmg/create-dmg) and a Developer ID Application certificate.

```bash
# One-time: store notarization credentials
xcrun notarytool store-credentials "hookqa-notary" \
    --apple-id YOUR_APPLE_ID \
    --team-id YOUR_TEAM_ID \
    --password APP_SPECIFIC_PASSWORD

# Build, sign, notarize, and staple
./scripts/build-dmg.sh
```

The script auto-detects your Developer ID signing identity from the keychain. Override with `SIGN_IDENTITY` env var if needed. Use `SKIP_NOTARIZE=1` to build a signed DMG without notarization.

> The app is **not sandboxed** — it needs filesystem access to `~/.claude/` and shell access for `bun` and `git`.

## Auto-Updates

HookQA uses [Sparkle 2](https://sparkle-project.org) for automatic updates, checked on launch. Manual checks available from the Hook tab.

---

<div align="center">

**Built for [Claude Code](https://claude.ai/code)** · Copyright 2026 Bitmoor Ltd

</div>
