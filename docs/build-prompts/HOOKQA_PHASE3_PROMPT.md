# HookQA — Phase 3 Kick-off Prompt

Read the spec at `HOOKQA_SPEC.md` to refresh context. You are implementing **Phase 3: Hook Management**. Phases 1–2 are complete — the app has a working menubar popover with Connection, Behaviour, and Review tabs, all writing to `~/.claude/hooks/hookqa.json`.

## Deliverables

1. **Bundle the hook script**
   - Add `hookqa-hook.ts` to the Xcode project's Resources (copy the current version from the project root or Resources folder)
   - It must be included in the app bundle so it can be copied to `~/.claude/hooks/` on install

2. **HookInstaller** (`Services/HookInstaller.swift`)

   This service manages the full hook lifecycle. It needs these capabilities:

   **Status checking:**
   - `hookScriptInstalled: Bool` — checks if `~/.claude/hooks/hookqa-hook.ts` exists
   - `hookRegistered: Bool` — checks if `~/.claude/settings.json` contains a Stop hook entry with a command containing `hookqa`
   - `bunAvailable: Bool` — runs `which bun` via ShellHelper and checks exit code
   - `installedVersion: String?` — reads the version comment from the second line of the installed hook script (line 1 is the shebang, line 2 is `// hookqa-hook v1.0.0`)
   - `bundledVersion: String` — reads the version from the bundled hook script in app Resources
   - `updateAvailable: Bool` — true if installed and bundled versions differ

   **Install:**
   - Creates `~/.claude/hooks/` directory if missing
   - Copies the bundled `hookqa-hook.ts` to `~/.claude/hooks/hookqa-hook.ts`
   - Sets executable permission (`chmod +x`) via ShellHelper
   - Reads `~/.claude/settings.json` (or creates it as `{}` if absent)
   - Parses the JSON, preserving ALL existing keys and structure
   - Adds the Stop hook entry to the hooks object:
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
   - If `hooks.Stop` already exists as an array, append the new entry to it (do not replace existing Stop hooks)
   - If `hooks` key doesn't exist, create it
   - Writes the updated JSON back, preserving formatting where possible
   - The timeout value should come from the current config's timeout setting

   **Uninstall:**
   - Removes `~/.claude/hooks/hookqa-hook.ts`
   - Reads `~/.claude/settings.json`
   - Finds and removes only the Stop hook entry whose command contains `hookqa` — leaves all other hooks untouched
   - If the Stop array is now empty, remove the Stop key
   - If the hooks object is now empty, remove the hooks key
   - Writes the updated JSON back

   **Update:**
   - Overwrites the installed hook script with the bundled version
   - Preserves the settings.json entry (just updates timeout if it changed)

3. **KeychainHelper** (`Utilities/KeychainHelper.swift`)
   - `save(key: String, service: String)` — saves a string to Keychain
   - `read(service: String) -> String?` — reads a string from Keychain
   - `delete(service: String)` — removes an entry
   - Service name: `co.uk.bitmoor.hookqa.apikey`
   - Used to store the Ollama API key securely
   - On config save, the SettingsManager should read the API key from Keychain and write it into `hookqa.json` so the hook script can access it without Keychain access

4. **HookTab** (`Views/HookTab.swift`)

   Replace the placeholder Hook tab with a full management view:

   - **Status section** — three status rows, each with a coloured dot and label:
     - Hook script: "Installed" (green) / "Not installed" (red)
     - Settings.json: "Registered" (green) / "Not registered" (red)
     - Bun: "Available" (green) / "Not found" (red) — if not found, show a small "Install Bun →" link that opens `https://bun.sh` in the browser
   - **Action buttons:**
     - "Install Hook" — visible when not installed. Calls HookInstaller.install()
     - "Uninstall Hook" — visible when installed. Shows confirmation alert first, then calls HookInstaller.uninstall()
     - "Update Hook" — visible when installed AND updateAvailable is true. Shows a badge/label like "v1.1 available". Calls HookInstaller.update()
     - "Reinstall Hook" — visible when installed. Overwrites with bundled version.
   - **Info section:**
     - Installed version (monospaced)
     - Bundled version (monospaced)
     - "Open Hook Script" button — opens the installed script in the default editor via `NSWorkspace.shared.open()`
   - All status checks should refresh when the tab appears and after any install/uninstall/update action

5. **Wire up API key to Connection tab**
   - Add a SecureField for the API key to the Connection tab (below the model picker)
   - Label: "API Key (optional)"
   - Placeholder: "For cloud Ollama endpoints"
   - Reads from / writes to Keychain via KeychainHelper
   - On change, SettingsManager writes the key into hookqa.json's `connection.apiKey` field

## Rules

- settings.json manipulation MUST preserve all existing content — never overwrite or lose other hooks/settings
- Use `JSONSerialization` for settings.json (not Codable) since we need to preserve arbitrary keys we don't model
- The HookInstaller should be `@Observable` so the UI reacts to status changes
- All file operations should handle errors gracefully — show user-facing error messages via alerts, never crash
- Test the full install → verify status → uninstall → verify status cycle
- Test that installing with an existing settings.json that has other hooks preserves those hooks
- Do not implement Phases 4–6
