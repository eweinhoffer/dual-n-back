# Peekaboo Screenshot Workflow

This project uses [Peekaboo](https://github.com/steipete/Peekaboo) to capture repeatable screenshots of app windows for docs and commits.

## Current screenshot output folder

Default output folder:

- `docs/screenshots/latest/`

Files:

- `main.png`
- `statistics.png`

## Prerequisites

1. Install Peekaboo:

```bash
brew install peekaboo
```

2. Grant permissions to the app that runs your terminal commands (Terminal/iTerm/Codex):

- `System Settings > Privacy & Security > Screen & System Audio Recording`
- `System Settings > Privacy & Security > Accessibility`

3. Verify permissions:

```bash
peekaboo list permissions
```

Both should show `Granted`.

4. Required CLI tools:

- `peekaboo`
- `jq`
- `rg` (ripgrep)

## One-command capture (recommended)

Run from project root:

```bash
./scripts/capture_peekaboo_screenshots.sh
```

Optional custom output directory:

```bash
./scripts/capture_peekaboo_screenshots.sh docs/screenshots/my-run
```

The script:

- opens `Dual N-Back.app`
- sizes the main window to the project default
- captures `main`
- opens and captures the `Statistics` window
- captures by explicit `window-id` (avoids accidental menu-bar captures)
- forces local execution with `--no-remote` for every Peekaboo command
- writes PNGs to `docs/screenshots/latest/` by default

## Build app before capture

If the app bundle is missing, build it first:

```bash
./BUILD_DOCK_APP.command
```

Expected app path:

- `Dual N-Back.app`

## Why this setup is safer and more stable

- Uses local-only Peekaboo execution (`--no-remote`) to reduce unintended data routing.
- Uses exact `window-id` targeting instead of generic frontmost captures.
- Uses deterministic app targeting via bundle ID: `io.dualnback.SwiftDualNBackPrototype`.
- Uses temporary files in `/tmp` with automatic cleanup (`trap`) so helper artifacts are not left in the repo.

## Security checklist before committing screenshots

1. Open each PNG and check for sensitive information.
2. Confirm no private notifications, personal files, or unrelated app content is visible.
3. Commit only the screenshot folder you intend to keep.
4. Prefer committing a single curated screenshot set instead of multiple historical runs.

Quick status check:

```bash
git status --short
```
