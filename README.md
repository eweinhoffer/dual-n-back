# Dual N-Back (macOS, SwiftUI)

A native macOS Dual N-Back training app built with SwiftUI.

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

### Adaptive N logic
After each session, the app updates N from average (visual+audio) accuracy:
- `>= 90%`: N increases by 1
- `75% to < 90%`: N unchanged
- `< 75%`: N decreases by 1 (minimum 1)

### UI additions
- End-of-session summary popup
- In-app Help sheet
- Settings sheet for visual highlight color presets/custom color
- App icon in `Assets.xcassets` for macOS app bundle/Dock

## Controls
- `F` or **Visual Match**: mark visual match
- `J` or **Auditory Match**: mark auditory match
- If both streams match, press both
- No response is needed for non-match trials

## Run The App

### Xcode (recommended)
1. Open `SwiftDualNBackPrototype/SwiftDualNBackPrototype.xcodeproj`
2. Choose scheme `SwiftDualNBackPrototype`
3. Choose target `My Mac`
4. Run with `Cmd+R`

### One-click helper (open project)
- Double-click `SwiftDualNBackPrototype/OPEN_XCODE.command`

### Build a Dock-ready app bundle
1. Run `./BUILD_DOCK_APP.command` from the repo root
2. The app is produced at `DualNBack.app`
3. Drag `DualNBack.app` into the Dock

## Project Structure
- `BUILD_DOCK_APP.command` (builds a Release app bundle at `DualNBack.app`)
- `SwiftDualNBackPrototype/Sources/SwiftDualNBackPrototype/`
  - `DualNBackPrototypeApp.swift` (game engine + SwiftUI views)
  - `main.swift` (entrypoint)
  - `Assets.xcassets/AppIcon.appiconset/` (Dock/app icon assets)
- `SwiftDualNBackPrototype/SwiftDualNBackPrototype.xcodeproj/` (Xcode project)
- `SwiftDualNBackPrototype/Package.swift` (SwiftPM manifest)
- `SwiftDualNBackPrototype/project.yml` (XcodeGen spec)
- `SwiftDualNBackPrototype/OPEN_XCODE.command` (open project helper)
- `LICENSE` (MIT)

## Security And Repo Hygiene
- `.gitignore` excludes local build products (`Build/`, `DualNBack.app`, `.dSYM`) and machine-specific Xcode files.
- Before publishing, run a quick secrets scan (API keys/tokens/passwords/private keys) as part of your release checklist.
