# HookQA — Phase 2 Kick-off Prompt

Read the spec at `HOOKQA_SPEC.md` to refresh context. You are implementing **Phase 2: Configuration UI**. Phase 1 is complete — the menubar app scaffold, SettingsManager, OllamaClient, and Connection tab are all working.

## Deliverables

1. **BehaviourTab** (`Views/BehaviourTab.swift`)
   - **Preset buttons row** — three buttons: Strict, Balanced, Light. Tapping one applies the preset values to all fields below. Preset values:
     - **Strict:** blockOnWarnings=true, minDiffLines=1, maxDiffLines=800, temperature=0.05, weights: correctness=10, completeness=10, specAdherence=8, codeQuality=6
     - **Balanced:** blockOnWarnings=false, minDiffLines=5, maxDiffLines=500, temperature=0.1, weights: correctness=10, completeness=8, specAdherence=6, codeQuality=4
     - **Light:** blockOnWarnings=false, minDiffLines=20, maxDiffLines=300, temperature=0.15, weights: correctness=10, completeness=4, specAdherence=2, codeQuality=2
   - **Block on Warnings** — toggle with description: "When enabled, warnings (not just criticals) will block Claude from stopping."
   - **Max Diff Lines** — slider or stepper, range 100–2000, step 100. Description: "Maximum diff lines sent to the model. Larger = better context but slower."
   - **Min Diff Lines** — slider or stepper, range 0–50, step 5. Description: "Skip QA for trivial changes below this threshold."
   - **Max Retries** — stepper, range 1–3. Description: "How many times Claude can retry fixes before the hook lets it stop."
   - **Timeout** — slider or stepper, range 30–300, step 10, suffix "s". Description: "Max seconds to wait for the model response."
   - **Temperature** — slider, range 0.0–1.0, step 0.05. Description: "Lower = more focused reviews. Higher = more varied critiques."

2. **ReviewTab** (`Views/ReviewTab.swift`)
   - Four weight sliders, each 0–10, step 1, with label and description:
     - **Correctness** (default 10) — "Bugs, logic errors, unhandled edge cases, broken control flow."
     - **Completeness** (default 8) — "Stubs, TODOs, placeholder implementations, half-finished features."
     - **Spec Adherence** (default 6) — "Does the code match what CLAUDE.md describes?"
     - **Code Quality** (default 4) — "Code smells, deeply nested logic, duplicated code, missing error handling."
   - **Custom Instructions** — multi-line TextEditor. Placeholder: "Optional: extra instructions appended to the QA prompt. E.g. 'This project uses Bun — flag any Node-specific APIs.'"

3. **Wire up tab navigation**
   - The placeholder tabs from Phase 1 for Behaviour and Review should now use the real views
   - Logs and Hook tabs remain as placeholders for now

4. **SettingsManager changes write to disk**
   - Every change to config via the Behaviour or Review tabs should flow through SettingsManager
   - SettingsManager debounces writes at 500ms — rapid slider dragging should not hammer the filesystem
   - Verify that changes persist across app relaunch (quit app, reopen, values should be restored)

## Rules

- All controls bind directly to the SettingsManager's config properties
- Use `@Observable` bindings — no manual state synchronisation
- Presets update both behaviour AND weights in a single config mutation (one debounced write, not multiple)
- Keep the UI visually consistent with the Connection tab from Phase 1
- Sliders should show their current value inline (e.g. "500" next to the Max Diff Lines slider)
- Do not touch the Connection tab, OllamaClient, or any Phase 1 code unless fixing a bug
- Do not implement Phases 3–6
- Test that config changes persist across app restart
