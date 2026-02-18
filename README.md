# Dual N-Back (macOS Swift App)

A native macOS Dual N-Back training app built with SwiftUI.

## What Dual N-Back Is
Dual N-Back is a working-memory training task where you track two streams at once:
- a **visual position** (highlighted square)
- an **auditory letter** (spoken letter)

On each trial, you decide whether the current visual and/or auditory stimulus matches the one from **N trials ago**.

## How This App Works

### Stimulus design
- 8 visual positions arranged in a 3x3 ring (center square is not used)
- Auditory letters are drawn from: `B F H J K L Q R`
- Visual and audio start together for each trial

### Timing
- Stimulus on-screen time: **500 ms**
- Gap before next trial: **2500 ms**
- Total pacing: **3000 ms per trial**
- 3-second spoken countdown before a session starts

### Session length
- Trials per session: **20 + N**

### Match composition per session
The generator plans approximately:
- 4 visual-only matches
- 4 auditory-only matches
- 2 simultaneous visual+auditory matches
- remaining trials are non-matches

### Scoring tracked per modality
- True Positive (TP)
- Miss
- False Positive (FP)

Accuracy is computed separately for visual and auditory; misses and false alarms are treated as errors.

### Adaptive leveling
After each session, the app adjusts N based on average modality accuracy:
- **>= 90%**: increase N
- **75% to < 90%**: keep N
- **< 75%**: decrease N (minimum 1)

## Controls
- `F` key or **Visual Match** button: register visual match
- `J` key or **Auditory Match** button: register auditory match
- If both modalities match, register both
- No response is needed for non-matches

## Audio quality approach
The app pre-generates spoken-letter clips at session start (using macOS voices) and reuses them during trials for lower latency and more consistent timing.

## Open and run

### One click
- Double-click:
`SwiftDualNBackPrototype/OPEN_XCODE.command`

### Or directly in Xcode
1. Open:
`SwiftDualNBackPrototype/SwiftDualNBackPrototype.xcodeproj`
2. Select scheme: `SwiftDualNBackPrototype`
3. Target: `My Mac`
4. Run: `Cmd+R`

## Project structure
- `SwiftDualNBackPrototype/` - native app source and Xcode project
- `LICENSE` - MIT license

## Status
Swift is the primary and active implementation on `main`.
