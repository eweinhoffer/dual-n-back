# Dual N-Back

This repo has two tracks:

1. `main`: Python/Tkinter baseline (`dual_n_back.py`)
2. `codex/swift-prototype`: native macOS SwiftUI app (`SwiftDualNBackPrototype`)

## Swift Prototype Rules (Implemented)

The Swift app follows these rules:

1. Board layout: 8 positions only (3x3 ring, no center square).
2. Stimulus timing: visual square + auditory letter start together for 500 ms.
3. Inter-stimulus gap: 2,500 ms.
4. Total trial pacing: 3,000 ms per trial (500 ms on + 2,500 ms gap).
5. Dual comparison rule: each trial compares current position and letter to the stimuli `n` trials back.
6. Response mapping:
   - `F`: visual match hit.
   - `J`: auditory match hit.
   - If both match, press both (`F` and `J`).
   - No response is required for non-matches.
7. Session length: `20 + n` trials.
8. Target mix per session (planned):
   - ~4 visual-only matches
   - ~4 auditory-only matches
   - ~2 simultaneous visual+auditory matches
   - Remaining are non-match trials
9. Adaptive leveling:
   - Compute visual and auditory accuracy separately.
   - Use average of modality accuracies for level adjustment.
   - `>= 90%`: increase `n`
   - `75% to <90%`: keep `n`
   - `<75%`: decrease `n` (minimum 1)
10. Scoring types tracked per modality:
   - True Positive (TP)
   - False Positive (FP)
   - Miss
11. Letter pool: `B F H J K L Q R`.

## Running the Swift app

Open in one click:
- `/Users/nateric/Documents/Custom Apps/Brain Games/Dual N-Back/SwiftDualNBackPrototype/OPEN_XCODE.command`

Or directly open:
- `/Users/nateric/Documents/Custom Apps/Brain Games/Dual N-Back/SwiftDualNBackPrototype/SwiftDualNBackPrototype.xcodeproj`

In Xcode:
1. Select scheme `SwiftDualNBackPrototype`
2. Target `My Mac`
3. Run (`Cmd+R`)

## Note on warnings fixed

The two MainActor warnings were addressed by routing timer closure callbacks back onto the main actor before mutating UI/game state.
