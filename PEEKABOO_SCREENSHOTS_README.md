# Peekaboo Screenshot Guide

Use this when you want fresh screenshots for the README or release docs.

## What this script creates

Default output folder:
- `docs/screenshots/latest/`

Default files:
- `main.png`
- `statistics.png`

## Requirements

Install Peekaboo:

```bash
brew install peekaboo
```

Make sure these commands exist:
- `peekaboo`
- `jq`
- `rg`

Grant permissions to the app running your terminal commands:
- `System Settings > Privacy & Security > Screen & System Audio Recording`
- `System Settings > Privacy & Security > Accessibility`

Check permissions:

```bash
peekaboo list permissions
```

Both permissions should show `Granted`.

## Build the app first

If `Dual N-Back.app` is missing, build it:

```bash
./BUILD_DOCK_APP.command
```

## Capture screenshots

Run from the repo root:

```bash
./scripts/capture_peekaboo_screenshots.sh
```

Use a custom output folder if you want to keep a separate capture set:

```bash
./scripts/capture_peekaboo_screenshots.sh docs/screenshots/my-run
```

## What the script does

- Opens `Dual N-Back.app`
- Sizes the main window to the project default
- Captures the main window
- Opens and captures the Statistics window
- Saves PNG files to `docs/screenshots/latest/` by default

## Security notes

- The script forces local Peekaboo execution with `--no-remote`
- It captures windows by explicit `window-id`
- It uses temporary files in `/tmp` and cleans them up automatically

Before committing screenshots:

1. Open each PNG and inspect it.
2. Make sure no private notifications, file names, or unrelated windows are visible.
3. Commit only the screenshot set you actually want to keep.

Quick check:

```bash
git status --short
```
