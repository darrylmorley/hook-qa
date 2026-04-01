# HookQA — Full Build Orchestration

You are building **HookQA**, a macOS menubar app. All specifications and phase prompts are in this project directory.

## Reference Documents

Read these files before starting:
- `HOOKQA_SPEC.md` — full product specification
- `CLAUDE.md` — development conventions and rules
- `HOOKQA_PHASE1_PROMPT.md` through `HOOKQA_PHASE6_PROMPT.md` — phase-by-phase deliverables

Read `HOOKQA_SPEC.md` and `CLAUDE.md` first to understand the full picture. Then execute each phase sequentially.

## Execution Model

You are the **orchestrator** (Opus). For each phase:

1. **Read** the phase prompt file (`HOOKQA_PHASE{N}_PROMPT.md`)
2. **Delegate implementation** to a sub-agent (Sonnet) with clear instructions from the phase prompt
3. **When the sub-agent completes**, review its work yourself:
   - Does the code compile? (`xcodebuild build -scheme HookQA -configuration Debug`)
   - Does it match every deliverable listed in the phase prompt?
   - Are there any missing files, broken imports, or stub implementations that should be real?
   - Does it follow the conventions in `CLAUDE.md`?
   - For Phase 4 (hook script): does it run without errors? (`bun hookqa-hook.ts` with test input)
4. **Fix any issues** found during review before proceeding
5. **Move to the next phase** — do not ask for confirmation between phases

## Phase Sequence

```
Phase 1: Scaffold & Core Services     → build + verify app launches
Phase 2: Configuration UI             → build + verify config persists across restart
Phase 3: Hook Management              → build + verify install/uninstall cycle works
Phase 4: Updated Hook Script          → build + verify script runs standalone with Bun
Phase 5: Logs & Status                → build + verify log parsing and menubar icon updates
Phase 6: Distribution                 → build + verify DMG script runs, onboarding flow works
```

## Sub-agent Instructions

When delegating to a sub-agent for implementation, pass it:
- The contents of the relevant phase prompt file
- The contents of `CLAUDE.md`
- Context about what was built in prior phases (file list, key types/services available)

The sub-agent should implement everything in the phase prompt and nothing beyond it.

## Verification Checklist (run after every phase)

- [ ] `xcodebuild build -scheme HookQA -configuration Debug` succeeds with no errors
- [ ] No warnings related to HookQA code (third-party warnings are acceptable)
- [ ] All files listed in the phase prompt exist at the correct paths
- [ ] No placeholder/stub code remains that the phase prompt said should be real
- [ ] SwiftUI previews are not broken (if applicable)

For Phase 4 specifically, also verify:
- [ ] `hookqa-hook.ts` has the shebang and version header
- [ ] The script parses valid JSON from stdin without crashing
- [ ] The bundled copy in Xcode Resources matches the working copy

For Phase 6 specifically, also verify:
- [ ] `scripts/build-dmg.sh` is executable and syntactically valid
- [ ] Sparkle SPM dependency resolves
- [ ] The onboarding flow detects first-run correctly

## Rules

- Do not skip phases or reorder them
- Do not ask for user input between phases — run autonomously to completion
- If a build fails after a phase, fix it before moving on
- Use sub-agents for implementation work, keep orchestration and review at the top level
- If a sub-agent produces code that doesn't compile, send it back with the errors rather than fixing it yourself at the orchestrator level — let the sub-agent learn from its mistakes
- Commit after each successful phase with message: `feat: complete HookQA phase N - {phase title}`

## Start

Begin now. Read the spec, read CLAUDE.md, then start Phase 1.
