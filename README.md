# Dual N-Back

This repo now has two implementation tracks:

1. `main`: Python/Tkinter baseline (`dual_n_back.py`)
2. `codex/swift-prototype`: native macOS SwiftUI prototype (`SwiftDualNBackPrototype/`)

## Python baseline

File:
- `dual_n_back.py`

Run:
```bash
python3 dual_n_back.py
```

Controls:
- `F` = position match
- `J` = auditory match

## Swift prototype (native macOS)

Folder:
- `SwiftDualNBackPrototype`

Tech stack:
- SwiftUI for UI
- AVFoundation speech for spoken letters
- AppKit key event monitor for `F`/`J`

Run:
```bash
cd SwiftDualNBackPrototype
swift run
```

Current prototype features:
- 3x3 visual grid with flashed position stimulus
- spoken letter stream for auditory stimulus
- configurable N, trials, stimulus duration, cycle duration
- dual response tracking (hits/misses/false alarms)
- keyboard controls:
  - `F` for position match
  - `J` for auditory-letter match

## Why move to Swift

For macOS, Swift removes Python interpreter/Tk backend fragility and gives a cleaner path for tightly synchronized audio + visual + keyboard interaction.
