# Dual N-Back Automations and Scripts

This file is the "how the project runs behind the scenes" companion to the main README.

Short version:

- I did not find a project-specific Codex desktop automation entry tied to this repo during the scan.
- The automation in this project mainly lives in shell scripts plus GitHub Actions workflows.
- Most of the workflows are aimed at build safety, release publishing, Homebrew support, screenshots, and security checks.

## Quick Map

| Item | Type | What it does |
|---|---|---|
| `BUILD_DOCK_APP.command` | Local script | Main local build command that creates `Dual N-Back.app` |
| `SwiftDualNBackPrototype/OPEN_XCODE.command` | Local script | Opens the Xcode project |
| `scripts/check_build_env.sh` | Local script | Verifies the Mac/Xcode environment before building |
| `scripts/capture_peekaboo_screenshots.sh` | Local script | Automates screenshot capture for docs |
| `scripts/security_scan.sh` | Local script | Scans the repo for obvious secrets and sensitive local-machine references |
| `scripts/update_from_github.sh` | Local script | Downloads and installs the latest GitHub Release build |
| `scripts/render_release_notes.sh` | Local script | Fills the release-notes template with the current tag/signing state |
| `scripts/update_homebrew_cask.sh` | Local script | Updates the Homebrew cask version and checksums |
| `.github/workflows/release.yml` | GitHub Action | Builds release ZIPs, creates checksum files, optionally signs them, publishes the release, and bumps the Homebrew cask |
| `.github/workflows/homebrew-smoke.yml` | GitHub Action | Installs the cask on Apple Silicon and Intel runners to make sure Homebrew install still works |
| `.github/workflows/security-scan.yml` | GitHub Action | Runs the repo security scan on pushes, PRs, and manual dispatch |

## Local Scripts

### `BUILD_DOCK_APP.command`

Purpose:

- This is the main local "build me an app" entry point.
- It runs the build-environment preflight first.
- It tries an Xcode Release build.
- If that path fails, it falls back to a Swift Package Manager build and manually packages the `.app`.

Run it with:

```bash
./BUILD_DOCK_APP.command
```

Important behavior:

- Output app path: `Dual N-Back.app`
- Uses `scripts/check_build_env.sh` first
- Uses `xcodebuild` first
- Falls back to `swift build -c release`
- Ad-hoc signs the fallback app with `codesign --force --sign -`

### `SwiftDualNBackPrototype/OPEN_XCODE.command`

Purpose:

- Convenience launcher for opening the Xcode project without browsing for it manually.

Run it with:

```bash
./SwiftDualNBackPrototype/OPEN_XCODE.command
```

Underlying command text:

```bash
open "SwiftDualNBackPrototype.xcodeproj"
```

### `scripts/check_build_env.sh`

Purpose:

- Checks that the machine has the right macOS build prerequisites before you try to build.

Run it with:

```bash
./scripts/check_build_env.sh
```

What it checks:

- `xcodebuild` exists
- Full Xcode is installed in `/Applications/Xcode.app`
- `xcode-select` points to full Xcode
- Xcode major version is at least `15`
- Xcode license is accepted
- First-launch components are installed

Why it matters:

- This script turns confusing Xcode/macOS setup failures into clearer PASS/FAIL messages.

### `scripts/capture_peekaboo_screenshots.sh`

Purpose:

- Automates README/release screenshots using Peekaboo.

Run it with:

```bash
./scripts/capture_peekaboo_screenshots.sh
```

Or with a custom output folder:

```bash
./scripts/capture_peekaboo_screenshots.sh docs/screenshots/my-run
```

What it does:

- Opens `Dual N-Back.app`
- Sizes the main window to a predictable capture size
- Captures the main window
- Opens and captures the Help sheet
- Opens and captures the Settings sheet
- Opens and captures the Statistics window

Security notes:

- Forces local Peekaboo execution with `--no-remote`
- Captures by explicit window id
- Uses temp files under `/tmp` and cleans them up
- Screenshots should always be reviewed before committing

### `scripts/security_scan.sh`

Purpose:

- Fast local scan for common "do not publish this" mistakes.

Run it with:

```bash
./scripts/security_scan.sh
```

What it looks for:

- Private key markers
- Common token patterns
- Hardcoded local machine paths
- Wi-Fi / SSID references
- Suspicious hardcoded credential assignments

Important exclusions:

- Ignores `.git`
- Ignores `Dual N-Back.app`
- Ignores screenshots
- Ignores the scan script itself

Security note:

- This is a good last step before commits or release work, but it is not a perfect scanner. Think of it as a smoke alarm, not a guarantee.

### `scripts/update_from_github.sh`

Purpose:

- Downloads the latest release, or a specific tagged release, and installs it locally with rollback protection.

Run it with:

```bash
./scripts/update_from_github.sh
```

Specific tag:

```bash
./scripts/update_from_github.sh v1.2.3
```

Behavior:

- Detects `arm64` vs `x86_64`
- Fetches release metadata from GitHub API
- Downloads the matching ZIP plus `SHA256SUMS.txt`
- Verifies checksums
- Verifies signatures too if `SHA256SUMS.txt.sig` and `release-signing-public.pem` are present
- Backs up the currently installed app before replacing it
- Restores the old app automatically if the update fails mid-way

Useful environment variable:

```bash
INSTALL_DIR=/some/path ./scripts/update_from_github.sh
```

### `scripts/render_release_notes.sh`

Purpose:

- Fills the release-notes template using the tag name and whether signing assets are present.

Run it with:

```bash
./scripts/render_release_notes.sh <tag> <signed:true|false> [template] [output]
```

Example:

```bash
./scripts/render_release_notes.sh v1.1.0 true .github/release-notes-template.md dist/release-notes.md
```

### `scripts/update_homebrew_cask.sh`

Purpose:

- Updates the Homebrew cask version and both architecture-specific SHA256 values.

Run it with:

```bash
./scripts/update_homebrew_cask.sh <tag> <arm_sha256> <intel_sha256> [cask_path]
```

Example:

```bash
./scripts/update_homebrew_cask.sh v1.1.0 <arm_sha> <intel_sha> Casks/dual-n-back.rb
```

Implementation detail:

- Uses a small embedded Ruby script to edit the version and checksum block safely.

## GitHub Actions Automations

### `.github/workflows/release.yml`

Purpose:

- This is the main release pipeline.

Trigger text:

```yaml
on:
  push:
    tags:
      - "v*"
  workflow_dispatch:
    inputs:
      release_tag:
```

What it automates:

- Builds Release app bundles for both `arm64` and `x86_64`
- Packages ZIP artifacts
- Creates per-arch checksum files, then a combined `SHA256SUMS.txt`
- Optionally signs the checksum manifest if `RELEASE_SIGNING_PRIVATE_KEY_B64` is configured
- Renders release notes from `.github/release-notes-template.md`
- Publishes assets to GitHub Releases
- On normal tagged releases, updates `Casks/dual-n-back.rb` and pushes the cask bump back to `main`

Core command text used inside the workflow:

```bash
xcodebuild \
  -project "$PROJECT_DIR/SwiftDualNBackPrototype.xcodeproj" \
  -scheme SwiftDualNBackPrototype \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  ARCHS="$XCODE_ARCH" \
  ONLY_ACTIVE_ARCH=YES \
  build
```

```bash
ditto -c -k --sequesterRsrc --keepParent "Dual N-Back.app" "dist/${ASSET_NAME}"
```

```bash
gh release create "$TAG_NAME" --title "$TAG_NAME" --notes-file "dist/release-notes.md"
gh release edit "$TAG_NAME" --notes-file "dist/release-notes.md"
gh release upload "$TAG_NAME" "${ASSETS[@]}" --clobber
```

Security-sensitive part:

- If the signing secret exists, the workflow decodes the private key from `RELEASE_SIGNING_PRIVATE_KEY_B64`, writes it to a temp file, creates `release-signing-public.pem`, and signs `SHA256SUMS.txt`.
- The private key itself should never be committed to the repo.

### `.github/workflows/homebrew-smoke.yml`

Purpose:

- Confirms that the Homebrew cask really installs on both Apple Silicon and Intel macOS runners.

Trigger text:

```yaml
on:
  push:
    branches:
      - main
    paths:
      - Casks/dual-n-back.rb
      - .github/workflows/homebrew-smoke.yml
  workflow_dispatch:
```

Core command text:

```bash
brew tap eweinhoffer/dual-n-back https://github.com/eweinhoffer/dual-n-back
brew install --cask dual-n-back
brew list --cask dual-n-back
```

What it verifies:

- App bundle lands in an expected install location
- Main executable exists
- Installed executable contains the expected architecture via `lipo -archs`

### `.github/workflows/security-scan.yml`

Purpose:

- Runs the repo security scan automatically in CI.

Trigger text:

```yaml
on:
  push:
    branches:
      - main
  pull_request:
  workflow_dispatch:
```

Core command text:

```bash
chmod +x scripts/security_scan.sh
./scripts/security_scan.sh
```

Why it matters:

- This gives an automated backstop against accidentally publishing secrets or machine-specific info.

## Release Inputs and Outputs

Inputs used by the automation:

- Git tag like `v1.1.0`
- Optional GitHub secret: `RELEASE_SIGNING_PRIVATE_KEY_B64`

Main output artifacts:

- `Dual-N-Back-macOS-unsigned-arm64.zip`
- `Dual-N-Back-macOS-unsigned-x86_64.zip`
- `SHA256SUMS.txt`
- Optional: `SHA256SUMS.txt.sig`
- Optional: `release-signing-public.pem`
- Updated `Casks/dual-n-back.rb` after a tagged stable release

## Practical Maintainer Notes

- If you are doing a release, the safest habit is:

```bash
./scripts/security_scan.sh
./BUILD_DOCK_APP.command
./scripts/capture_peekaboo_screenshots.sh
```

- Then tag and push the release so GitHub Actions can do the packaging/publishing work.
- Before publishing anything, inspect screenshots and make sure no personal notifications, local file names, or machine-specific details slipped in.
- If you ever add a real local automation outside the repo for this project, add it to this file too so future-you does not have to rediscover it.
