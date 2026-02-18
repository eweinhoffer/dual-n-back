# Dual N-Back

This repository currently contains two tracks:

1. Python/Tkinter prototype (current baseline on `main`)
2. Swift/macOS prototype (in progress on `codex/swift-prototype`)

## Why we are moving to Swift
The Python prototype worked functionally but hit macOS environment friction:
- `tkinter` compatibility issues depending on interpreter/toolchain
- audio backend instability and speech-quality concerns
- timing sensitivity between visual flash and spoken stimuli

For a timing-sensitive Mac app, Swift + SwiftUI + AVFoundation is a better fit.

## Current baseline: Python version
File:
- `dual_n_back.py`

Behavior:
- Visual 3x3 position stimulus
- Keyboard responses:
  - `F` = position match
  - `J` = auditory match
- Spoken-letter auditory stream on macOS
- Configurable N level, trial count, and timing

Run:
```bash
python3 dual_n_back.py
```

## Next branch: Swift prototype
Goal on the Swift branch:
- Native macOS app (SwiftUI)
- Deterministic stimulus timing loop
- Natural spoken letters via Apple speech APIs
- Keyboard input handling for dual responses

This split keeps the Python implementation preserved while moving forward with a native architecture.
