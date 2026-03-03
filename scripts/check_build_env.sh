#!/bin/zsh
set -euo pipefail

MIN_XCODE_MAJOR=15
EXPECTED_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
FAILURES=0

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

warn() {
  echo "WARN: $1"
}

echo "Checking macOS build environment for Dual N-Back..."

if ! command -v xcodebuild >/dev/null 2>&1; then
  fail "xcodebuild is not available."
  echo "  Fix: install full Xcode from the App Store, then run:"
  echo "       sudo xcode-select -s $EXPECTED_DEVELOPER_DIR"
else
  pass "xcodebuild is installed."
fi

if [[ ! -d "$EXPECTED_DEVELOPER_DIR" ]]; then
  fail "Full Xcode app was not found at /Applications/Xcode.app."
  echo "  Fix: install Xcode, launch it once, then run:"
  echo "       sudo xcode-select -s $EXPECTED_DEVELOPER_DIR"
else
  pass "Full Xcode.app is installed in /Applications."
fi

ACTIVE_DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ -z "$ACTIVE_DEVELOPER_DIR" ]]; then
  fail "No active developer directory is configured."
  echo "  Fix: run:"
  echo "       sudo xcode-select -s $EXPECTED_DEVELOPER_DIR"
else
  pass "Active developer directory is set: $ACTIVE_DEVELOPER_DIR"
  if [[ "$ACTIVE_DEVELOPER_DIR" != "$EXPECTED_DEVELOPER_DIR" ]]; then
    fail "Active developer directory is not pointing to full Xcode."
    echo "  Fix: run:"
    echo "       sudo xcode-select -s $EXPECTED_DEVELOPER_DIR"
  else
    pass "Active developer directory points to full Xcode."
  fi
fi

XCODE_VERSION_LINE="$(xcodebuild -version 2>/dev/null | head -n 1 || true)"
XCODE_MAJOR="$(echo "$XCODE_VERSION_LINE" | sed -n 's/^Xcode \([0-9][0-9]*\).*/\1/p')"
if [[ -z "$XCODE_MAJOR" ]]; then
  fail "Unable to detect Xcode version from: ${XCODE_VERSION_LINE:-<empty>}"
  echo "  Fix: reinstall or open Xcode once, then retry."
else
  pass "Detected $XCODE_VERSION_LINE"
  if (( XCODE_MAJOR < MIN_XCODE_MAJOR )); then
    fail "Xcode major version must be >= $MIN_XCODE_MAJOR."
    echo "  Fix: update Xcode from the App Store to version $MIN_XCODE_MAJOR or newer."
  else
    pass "Xcode version satisfies minimum requirement (>= $MIN_XCODE_MAJOR)."
  fi
fi

if xcodebuild -license check >/dev/null 2>&1; then
  pass "Xcode license is accepted."
else
  fail "Xcode license has not been accepted."
  echo "  Fix: run:"
  echo "       sudo xcodebuild -license"
  echo "       # or non-interactive:"
  echo "       sudo xcodebuild -license accept"
fi

if xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  pass "Xcode first-launch components are installed."
else
  if xcodebuild -help 2>/dev/null | grep -q "checkFirstLaunchStatus"; then
    fail "Xcode first-launch setup is incomplete."
  else
    warn "Could not automatically verify first-launch status on this Xcode version."
  fi
  echo "  Fix: run:"
  echo "       sudo xcodebuild -runFirstLaunch"
  echo "       sudo xcodebuild -license accept"
fi

if (( FAILURES > 0 )); then
  echo
  echo "Build environment check failed with $FAILURES issue(s)."
  exit 1
fi

echo
echo "Build environment check passed."
