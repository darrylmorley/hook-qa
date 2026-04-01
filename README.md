# HookQA

HookQA is a macOS menubar app that adds automatic quality-assurance review to [Claude Code](https://claude.ai/code). It intercepts Claude's Stop hook after every task completion, sends the conversation transcript to a local [Ollama](https://ollama.com) model, and either approves the result or feeds an issue report back to Claude to fix.

## Installation

1. Download the latest `HookQA-x.x.dmg` from the [Releases](https://github.com/bitmoor/hook-qa/releases) page.
2. Open the DMG and drag **HookQA.app** to your Applications folder.
3. Launch HookQA — it appears as a shield icon in your menu bar.
4. On first launch the onboarding wizard walks you through connecting to Ollama and installing the hook.

> **Requirements:** macOS 14 (Sonoma) or later, [Bun](https://bun.sh), [Ollama](https://ollama.com) with at least one model pulled.

## First Launch Walkthrough

The four-step onboarding wizard guides you through:

1. **Welcome** — overview of what HookQA does.
2. **Connect** — enter your Ollama endpoint (default: `http://localhost:11434`) and choose a model.
3. **Install** — installs `~/.claude/hooks/hookqa-hook.ts` and registers the Stop hook in Claude Code's `settings.json`.
4. **Done** — you're ready. The shield icon in the menu bar shows your connection status.

You can skip onboarding at any time; settings are accessible via the menubar popover.

## How It Works

### Stop Hook Flow

```
Claude Code finishes a task
        │
        ▼
hookqa-hook.ts (Stop hook, runs via bun)
        │
        ├─ Reads conversation transcript from stdin (JSON)
        ├─ Sends transcript + system prompt to Ollama
        │
        ▼
Ollama reviews the work
        │
        ├─ APPROVE  → hook exits 0, Claude Code continues
        └─ BLOCK    → hook exits non-zero with a feedback message
                      Claude Code sees the message and tries to fix the issue
```

The hook script is written in TypeScript and executed by Bun. It reads the `hookqa.json` config from `~/.claude/hooks/` to know which endpoint and model to use.

## Configuration

Settings are stored in `~/.claude/hooks/hookqa.json` and managed through the app UI.

| Setting | Description | Default |
|---|---|---|
| `ollamaUrl` | Ollama HTTP endpoint | `http://localhost:11434` |
| `model` | Model name | `qwen3:30b-coder` |
| `timeout` | Request timeout in seconds | `120` |
| `behaviour.mode` | Review mode: `balanced`, `strict`, `lenient` | `balanced` |
| `behaviour.maxRetries` | How many times Claude may retry before approving anyway | `2` |

### Project-Level Overrides

You can override settings per project by adding a `.hookqa.json` file to your project root. The hook script merges project-level config over the global config, so you can use a different model or stricter settings for specific projects:

```json
{
  "model": "qwen3:72b",
  "behaviour": {
    "mode": "strict"
  }
}
```

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
# Output: build/HookQA-1.0.dmg
```

## Auto-Updates

HookQA uses [Sparkle 2](https://sparkle-project.org) for automatic updates. The appcast is hosted at `https://hookqa.bitmoor.co.uk/appcast.xml`. Updates are checked automatically on launch; you can also trigger a manual check from the Hook tab.

## License

Copyright © 2024 Bitmoor Ltd. All rights reserved.
