# Dual N-Back (macOS, SwiftUI)

A native macOS Dual N-Back training app built with SwiftUI.

## Screenshots

### Main

![Dual N-Back main screen](docs/screenshots/latest/main.png)

### Statistics

![Dual N-Back statistics screen](docs/screenshots/latest/statistics.png)

## What Dual N-Back Is
You track two streams at once on each trial:
- Visual: the highlighted square position
- Auditory: the spoken letter

You respond when either stream matches what appeared **N trials ago**.

## Current App Behavior

### Stimulus design
- Visual grid uses 8 positions in a 3x3 ring (center unused)
- Auditory letters come from: `B F H J K L Q R`
- Visual and audio are presented together each trial

### Timing
- Stimulus visible: `500 ms`
- Inter-trial gap: `2500 ms`
- Total pacing: `3000 ms` per trial
- Session starts with a spoken `3, 2, 1` countdown
- The game starts `500 ms` after the spoken `1`

### Session length and match mix
- Trials per session: `20 + N`
- Planned match distribution per session:
  - `4` visual-only matches
  - `4` auditory-only matches
  - `2` dual matches
  - remaining trials are non-matches

### Scoring
Per modality (visual/audio), the app tracks:
- True Positives (TP)
- Misses
- False Positives (FP)

Accuracy formula:
- `accuracy = TP / (TP + Misses + FP)`

### Score history (new)
- Each completed session is saved with:
  - visual/audio accuracy percentages
  - date + time completed
  - `N` level before and after adaptation
  - TP/Miss/FP counts for each modality
- History is stored locally as JSON in macOS Application Support:
  - `~/Library/Application Support/DualNBack/score_history.json`
- The app includes:
  - a **Statistics** screen with a visual/audio accuracy chart by session index (equal spacing, straight-line segments)
  - a full session list showing timestamp, `N` transition, and percentages
  - a one-click **Export CSV** action from Statistics for analysis in Numbers/Excel
  - exported CSV defaults to a filename with the included date range
  - a **Clear Statistics Data** action that requires explicit confirmation

### Adaptive N logic
After each session, the app updates N from average (visual+audio) accuracy:
- `>= 90%`: N increases by 1
- `75% to < 90%`: N unchanged
- `< 75%`: N decreases by 1 (minimum 1)

### UI additions
- End-of-session summary popup
- In-app Help sheet
- Settings sheet for visual highlight color presets/custom color
- Main game window defaults to a compact width while remaining resizable
- Statistics opens as a separate resizable window
- Settings toggle for showing/hiding live status text (example: `Trial 2/22 | N=2`)
- Settings controls for app-open level behavior:
  - resume at last level (default)
  - or start at a user-selected level (1...8)
- App icon in `Assets.xcassets` for macOS app bundle/Dock

## Controls
- `F` or **Visual Match**: mark visual match
- `J` or **Auditory Match**: mark auditory match
- If both streams match, press both
- No response is needed for non-match trials

## Install (Recommended For Most Users)

1. Open the latest release:
   - `https://github.com/eweinhoffer/dual-n-back/releases/latest`
2. Find your Mac architecture:
   - `uname -m`
   - `arm64` = Apple Silicon, `x86_64` = Intel
3. Download:
   - `Dual-N-Back-macOS-unsigned-arm64.zip` (Apple Silicon)
   - or `Dual-N-Back-macOS-unsigned-x86_64.zip` (Intel)
4. Download `SHA256SUMS.txt` from the same release.
5. Verify checksum:
   - `shasum -a 256 -c SHA256SUMS.txt`
6. If signature assets are present, verify signature too:
   - `openssl dgst -sha256 -verify release-signing-public.pem -signature SHA256SUMS.txt.sig SHA256SUMS.txt`
7. Unzip and move `Dual N-Back.app` to `/Applications`
8. Drag `Dual N-Back.app` into the Dock

## Install With Homebrew (Custom Tap)

1. Add this repo as a tap:
   - `brew tap eweinhoffer/dual-n-back https://github.com/eweinhoffer/dual-n-back`
2. Install the cask:
   - `brew install --cask dual-n-back`
3. Upgrade later:
   - `brew upgrade --cask dual-n-back`

Notes:
- This uses a custom tap (`Casks/dual-n-back.rb`), not Homebrew core.
- The cask tracks latest unsigned artifacts and currently uses `sha256 :no_check`.
- For better security, still verify `SHA256SUMS.txt` (and signature if present) from the release.

### Important Security Note (Interim Unsigned Build)
- The current release ZIP is unsigned while Apple notarization is being set up.
- On first launch, macOS Gatekeeper may block the app.
- If blocked, right-click the app, choose **Open**, then confirm.
- If needed: `System Settings > Privacy & Security > Open Anyway`.
- Do not install app bundles from unofficial links; use GitHub Releases only.

## Build From Source (Developer Path)

### Requirements
- macOS 13 or newer
- Full Xcode 15+ installed in `/Applications/Xcode.app` (Command Line Tools alone are not enough)
- Active developer directory set to full Xcode:
  - `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- First-launch components installed:
  - `sudo xcodebuild -runFirstLaunch`
- Xcode license accepted:
  - `sudo xcodebuild -license accept`

### Preflight check
- Run:
  - `./scripts/check_build_env.sh`
- This prints PASS/FAIL checks with exact fix commands.

### Build a Dock-ready app bundle
1. Run `./BUILD_DOCK_APP.command` from the repo root
2. The app is produced at `Dual N-Back.app`
3. Drag `Dual N-Back.app` into the Dock

### Xcode (manual run path)
1. Open `SwiftDualNBackPrototype/SwiftDualNBackPrototype.xcodeproj`
2. Choose scheme `SwiftDualNBackPrototype`
3. Choose target `My Mac`
4. Run with `Cmd+R`

### One-click helper (open project)
- Double-click `SwiftDualNBackPrototype/OPEN_XCODE.command`

## Build Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `xcodebuild: command not found` | Xcode not installed | Install Xcode, then run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| Active developer directory points to CommandLineTools | Full Xcode not selected | Run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| `xcodebuild` first-launch/license errors | Xcode setup incomplete | Run `sudo xcodebuild -runFirstLaunch` and `sudo xcodebuild -license accept` |
| Build script cannot find `Dual N-Back.app` | Build failed or wrong destination | Re-run `./scripts/check_build_env.sh`, then build again |
| “Using the first of multiple matching destinations” | Ambiguous build destination | `BUILD_DOCK_APP.command` now pins destination to `platform=macOS` |

## Automated Release Artifacts

- CI publishes architecture-specific ZIPs when you push a Git tag like `v1.0.0`:
  - `Dual-N-Back-macOS-unsigned-arm64.zip`
  - `Dual-N-Back-macOS-unsigned-x86_64.zip`
- CI also publishes:
  - `SHA256SUMS.txt` (checksum manifest)
  - optional `SHA256SUMS.txt.sig` + `release-signing-public.pem` (if `RELEASE_SIGNING_PRIVATE_KEY_B64` is configured)
- You can also run the release workflow manually from GitHub Actions (`workflow_dispatch`) for dry-run builds or release backfills.
- Release notes are rendered from:
  - `.github/release-notes-template.md`
- Optional checksum signing setup:
  - `docs/RELEASE_SIGNING_SETUP.md`
- Planned next phase: replace unsigned ZIP as primary artifact with signed/notarized DMG.

### Capture app screenshots with Peekaboo (CLI)
1. Install Peekaboo:
   - `brew install peekaboo`
2. Grant required macOS permissions for your terminal app:
   - `System Settings > Privacy & Security > Screen & System Audio Recording`
   - `System Settings > Privacy & Security > Accessibility`
3. Run:
   - `./scripts/capture_peekaboo_screenshots.sh`
4. Images are saved to:
   - `docs/screenshots/latest/` (or your custom path argument)
5. Full workflow and security notes:
   - `PEEKABOO_SCREENSHOTS_README.md`

Security note:
- Screenshots can contain personal information (notifications, file names, app state).
- Review images before committing to GitHub.

### If you add/move source files
- Regenerate the Xcode project with `xcodegen` from `SwiftDualNBackPrototype/`

## Project Structure
- `BUILD_DOCK_APP.command` (builds a Release app bundle at `Dual N-Back.app`)
- `Casks/dual-n-back.rb` (custom Homebrew cask for this repo tap)
- `scripts/check_build_env.sh` (Xcode/toolchain preflight checks with actionable fixes)
- `scripts/render_release_notes.sh` (renders release notes from template + signing state)
- `scripts/capture_peekaboo_screenshots.sh` (automated window screenshots via Peekaboo CLI)
- `PEEKABOO_SCREENSHOTS_README.md` (detailed screenshot workflow + security checklist)
- `docs/RELEASE_SIGNING_SETUP.md` (optional release signature setup for CI)
- `.github/workflows/release.yml` (tag-triggered macOS release artifact pipeline)
- `.github/release-notes-template.md` (release notes template used by CI)
- `SwiftDualNBackPrototype/Sources/SwiftDualNBackPrototype/`
  - `DualNBackPrototypeApp.swift` (app entry only)
  - `Engine/GameEngine.swift` (session lifecycle, trial generation, scoring, persistence hooks)
  - `Models/SessionScore.swift` (saved session data model)
  - `Storage/StatisticsStore.swift` (JSON load/save/clear in Application Support)
  - `Views/ContentView.swift` (main gameplay UI + sheets)
  - `Views/StatisticsView.swift` (Statistics UI + chart + CSV export)
  - `Views/SettingsView.swift` (color + startup + live-status preferences)
  - `Views/HelpView.swift` (help sheet)
  - `Views/KeyCaptureView.swift` (keyboard capture for `F` and `J`)
  - `main.swift` (entrypoint)
  - `Assets.xcassets/AppIcon.appiconset/` (Dock/app icon assets)
- `SwiftDualNBackPrototype/SwiftDualNBackPrototype.xcodeproj/` (Xcode project)
- `SwiftDualNBackPrototype/Package.swift` (SwiftPM manifest)
- `SwiftDualNBackPrototype/project.yml` (XcodeGen spec)
- `SwiftDualNBackPrototype/OPEN_XCODE.command` (open project helper)
- `LICENSE` (MIT)

## Security And Repo Hygiene
- `.gitignore` excludes local build products (`Build/`, `DualNBack.app`, `Dual N-Back.app`, `.dSYM`) and machine-specific Xcode files.
- Before publishing, run a quick secrets scan (API keys/tokens/passwords/private keys) as part of your release checklist.
- Never commit signing certificates, keychains, notarization credentials, or app-specific passwords.
