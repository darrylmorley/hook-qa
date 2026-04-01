# HookQA — Phase 6 Kick-off Prompt

Read the spec at `HOOKQA_SPEC.md` to refresh context. You are implementing **Phase 6: Distribution**. Phases 1–5 are complete — HookQA is a fully functional menubar app with config management, hook installation, log viewing, and status monitoring.

This phase makes the app distributable and adds quality-of-life features.

## Deliverables

1. **Sparkle 2 integration**
   - Add Sparkle 2 as a Swift Package dependency (https://github.com/sparkle-project/Sparkle)
   - Configure the `SUFeedURL` in Info.plist — use placeholder URL: `https://hookqa.bitmoor.co.uk/appcast.xml`
   - Add `SUPublicEDKey` in Info.plist — generate a placeholder EdDSA key pair for now (document where the real keys go)
   - Add an `SPUStandardUpdaterController` and wire it up
   - Add a "Check for Updates" menu item or button in the Hook Management tab
   - Sparkle should check for updates on launch (with standard Sparkle UI for update prompts)
   - Add the necessary entitlements for network access if sandboxed, or document that the app is not sandboxed

2. **DMG build script**
   - Create a `scripts/build-dmg.sh` script that:
     - Builds the app in Release configuration: `xcodebuild -scheme HookQA -configuration Release -archivePath build/HookQA.xcarchive archive`
     - Exports the archive to a .app
     - Creates a DMG using `create-dmg` (document that it needs `brew install create-dmg`):
       - Window size 600x400
       - App icon on the left, symlink to /Applications on the right
       - Background image (optional — can be plain for now)
       - Volume name: "HookQA"
       - Output filename: `HookQA-{version}.dmg` (read version from Info.plist or pass as argument)
     - The script should be runnable from the project root: `./scripts/build-dmg.sh`
   - Add a `.gitignore` entry for `build/`

3. **Launch at Login**
   - Add a "Launch at Login" toggle to the Hook Management tab (below the existing content)
   - Use `SMAppService.mainApp` to register/unregister (macOS 13+)
   - Read the current state on view appear to set the toggle correctly
   - Handle errors gracefully (e.g. if the user denies permission)

4. **First-run onboarding**
   - On first launch (detect via absence of `~/.claude/hooks/hookqa.json`), show a simple onboarding flow in the popover:
     - **Step 1:** Welcome message: "HookQA adds automated QA review to your Claude Code workflow. It uses an Ollama model to review your code changes before Claude finishes a task."
     - **Step 2:** Ollama endpoint configuration (reuse the Connection tab's endpoint field and model picker)
     - **Step 3:** "Install the hook now?" with Install button. Shows the three status indicators (hook script, settings.json, Bun) and the Install button from HookTab.
     - **Step 4:** "You're all set!" with a summary of what was configured and a "Done" button that closes the onboarding and shows the normal popover.
   - Use a simple step indicator (dots or "Step 1 of 4")
   - The onboarding can be a separate view that replaces the normal popover content until completed
   - Store a `onboardingComplete` flag in UserDefaults (not in hookqa.json — this is app-level state, not hook config)

5. **About / app info**
   - Add a small footer or section at the bottom of the popover (visible on all tabs) showing:
     - "HookQA v{version}" — read from Bundle.main.infoDictionary
     - "Quit" button
   - Or alternatively, add a right-click context menu on the menubar icon with: "About HookQA", "Check for Updates", "Quit"

6. **README.md**
   - Create a project README covering:
     - What HookQA is (one paragraph)
     - Installation (download DMG, drag to Applications)
     - First launch walkthrough
     - How it works (the Stop hook flow diagram from the spec)
     - Configuration overview (link to the tabs)
     - Project-level overrides (`.claude/hookqa.json`)
     - Building from source (`xcodebuild` or open in Xcode)
     - Requirements: macOS 14+, Bun, Ollama

## Rules

- Sparkle 2 via Swift Package Manager — not CocoaPods or Carthage
- The DMG script should work on a clean checkout (no hardcoded paths to your machine)
- Launch at Login must use the modern `SMAppService` API, not the deprecated `SMLoginItemSetEnabled`
- First-run onboarding should be skippable (a "Skip" button on each step)
- The app should not be sandboxed — it needs to read/write `~/.claude/` and run shell commands. Document this in the README.
- Keep the onboarding simple and fast — the user should be able to get through it in under a minute
- Test the full flow: fresh install (delete hookqa.json + hook script) → onboarding → install hook → verify everything works
- This is the final phase — after this, HookQA is feature-complete and distributable
