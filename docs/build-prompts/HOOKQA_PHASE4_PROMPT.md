# HookQA — Phase 4 Kick-off Prompt

Read the spec at `HOOKQA_SPEC.md` to refresh context. You are implementing **Phase 4: Updated Hook Script**. Phases 1–3 are complete — the Swift app is working with config management, Ollama connectivity, and hook installation. The app writes config to `~/.claude/hooks/hookqa.json` and installs the hook script to `~/.claude/hooks/hookqa-hook.ts`.

This phase rewrites the hook script so it reads the config file and uses all the settings the app provides.

## Deliverables

1. **Rewrite `hookqa-hook.ts`**

   This is a Bun/TypeScript script that runs as a Claude Code Stop hook. It must be fully standalone — no external dependencies beyond Bun built-ins.

   **Config loading (three-tier fallback):**
   - Primary: read and parse `~/.claude/hooks/hookqa.json` (expand `~` to `process.env.HOME` or `Bun.env.HOME`)
   - Fallback: env vars (`QA_OLLAMA_MODEL`, `QA_OLLAMA_URL`, `QA_MAX_DIFF_LINES`, `QA_ENABLED`, `QA_LOG_FILE`)
   - Default: hardcoded defaults matching the spec
   - Note: the `logFile` path in config may contain `~` — always expand it before writing

   **Project-level overrides:**
   - After loading global config, check if `.claude/hookqa.json` exists in the current working directory
   - If found, parse it and deep-merge over the global config (project values override global values)
   - Only `behaviour` and `review` sections are expected in project overrides — `connection` and `logging` come from global only

   **Deep merge logic:**
   - Objects merge recursively (project keys override global keys, unset keys keep global values)
   - Arrays and primitives are replaced entirely
   - Example: if global weights are `{correctness:10, completeness:8, specAdherence:6, codeQuality:4}` and project override has `{completeness:10}`, the merged result is `{correctness:10, completeness:10, specAdherence:6, codeQuality:4}`

   **Dynamic QA prompt from weights:**
   - Build the grading criteria section of the prompt using the weight values
   - Criteria with weight >= 8: labelled "PRIMARY focus"
   - Criteria with weight 4–7: labelled "Secondary focus"
   - Criteria with weight 1–3: labelled "Light check"
   - Criteria with weight 0: omitted entirely
   - Example output in prompt: "1. **Correctness** [PRIMARY focus, weight 10/10]: Bugs, logic errors, unhandled edge cases, broken control flow."
   - Append `customInstructions` to the end of the prompt if non-empty, under a "## Additional Instructions" heading

   **maxRetries support:**
   - On receiving hook input, read `stop_hook_active` from stdin JSON
   - Track retry count via temp file at `/tmp/hookqa-{session_id}-retries`
   - On first run (no temp file): if QA fails, create temp file with count=1, exit 2
   - On subsequent runs: read temp file, increment count. If count >= maxRetries, delete temp file and exit 0 (let Claude stop). Otherwise write incremented count, exit 2.
   - On QA pass: delete temp file if it exists, exit 0
   - The `stop_hook_active` flag from Claude Code is still checked — but instead of immediately exiting 0, use it as one signal alongside the retry counter. If `stop_hook_active` is true AND retries >= maxRetries, exit 0. If `stop_hook_active` is true but retries < maxRetries, continue with QA (this lets the retry loop work properly).
   - **Concrete example with maxRetries=2:**
     1. Claude stops → hook runs, QA fails → write retries=1, exit 2 → Claude continues
     2. Claude stops → hook runs (stop_hook_active=true, retries=1 < 2) → QA still fails → write retries=2, exit 2 → Claude continues
     3. Claude stops → hook runs (stop_hook_active=true, retries=2 >= 2) → delete temp file, exit 0 → Claude stops

   **blockOnWarnings:**
   - Default behaviour: only critical findings trigger exit 2
   - When `blockOnWarnings` is true: both critical AND warning findings trigger exit 2

   **minDiffLines:**
   - After collecting the git diff, count the number of actual diff lines (excluding section headers like "=== STAGED CHANGES ===")
   - If below `minDiffLines`, skip QA entirely — exit 0 with a log entry of verdict "SKIPPED"

   **apiKey:**
   - Read from `config.connection.apiKey`
   - If non-null and non-empty, include `Authorization: Bearer {apiKey}` header in the Ollama API request

   **JSONL structured logging:**
   - If logging is enabled, write one JSONL entry per QA run to the configured log file
   - Entry format:
     ```json
     {"timestamp":"2026-04-01T10:30:00.000Z","project":"ss-stores","model":"qwen3:30b-coder","verdict":"PASS|FAIL|ERROR|SKIPPED","findings":0,"criticals":0,"warnings":0,"summary":"...","durationMs":45200}
     ```
   - `project` is derived from: git remote origin URL (extract repo name), falling back to the current directory name
   - `durationMs` is the wall-clock time of the Ollama API call only (not the full hook execution)
   - Append to the file (do not overwrite)

   **Retry temp file cleanup:**
   - On exit 0 (pass or max retries reached), delete `/tmp/hookqa-{session_id}-retries` if it exists

2. **Version header**
   - The first line of the script must be the shebang: `#!/usr/bin/env bun`
   - The second line must be a version comment: `// hookqa-hook v1.0.0`
   - The app's HookInstaller reads this line to compare versions

3. **Update the bundled copy in Resources**
   - Replace the `hookqa-hook.ts` in the Xcode project's Resources with the new version
   - The app should bundle this new version so that "Install Hook" and "Update Hook" deploy it

## Testing

Test the following scenarios manually or describe how to test them:

- **Config loading:** Remove `hookqa.json`, verify env var fallback works. Remove env vars, verify defaults.
- **Project override:** Create a `.claude/hookqa.json` in a test project with `{"review":{"weights":{"completeness":10}}}`, verify the merged prompt shows completeness as PRIMARY.
- **Retry logic:** Set maxRetries=2. On first fail, verify temp file created with count=1. On second fail, verify count=2. On third invocation, verify exit 0 and temp file deleted.
- **minDiffLines:** Make a 3-line change with minDiffLines=5, verify QA is skipped with SKIPPED verdict in log.
- **blockOnWarnings:** Trigger a warning-only result with blockOnWarnings=false (should pass) and true (should fail).
- **JSONL logging:** Verify log entries are appended, not overwritten. Verify project name extraction from git remote.

## Rules

- The script must work standalone with just Bun — no npm dependencies
- Use `Bun.file()` and `Bun.write()` for all file operations
- Use `Bun.$` for git commands
- All errors should be caught — the hook must never crash Claude Code. On any unhandled error, exit 0.
- Keep the script under 500 lines if possible — it needs to be readable
- Do not modify any Swift code in this phase unless updating the bundled resource
- Do not implement Phases 5–6
