#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$REPO_DIR/Dual N-Back.app"
APP_NAME="Dual N-Back"
APP_BUNDLE_ID="io.dualnback.SwiftDualNBackPrototype"
OUT_DIR="${1:-$REPO_DIR/docs/screenshots/latest}"
TMP_SEE_PATH="$(mktemp /tmp/dual_n_back_peekaboo_XXXXXX.png)"

cleanup() {
  rm -f "$TMP_SEE_PATH"
}

trap cleanup EXIT INT TERM

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
}

pb() {
  # Force local execution so no remote bridge host is used for captures.
  peekaboo "$@" --no-remote
}

click_actionable_label() {
  local label="$1"
  local snapshot_text
  local snapshot_id
  local element_id

  snapshot_text="$(pb see --app "$APP_BUNDLE_ID" --mode window --path "$TMP_SEE_PATH")"
  snapshot_id="$(echo "$snapshot_text" | rg -o 'Snapshot ID: [A-Z0-9-]+' | head -n1 | sed 's/Snapshot ID: //')"
  element_id="$(echo "$snapshot_text" | rg -F "(button) - ${label}" | rg -o 'elem_[0-9]+' | head -n1)"

  if [ -z "$snapshot_id" ] || [ -z "$element_id" ]; then
    echo "Could not find actionable element for label: $label"
    exit 3
  fi

  pb click --snapshot "$snapshot_id" --on "$element_id" --app "$APP_BUNDLE_ID"
}

window_id_for_title() {
  local title="$1"
  local windows_json
  local window_id

  windows_json="$(pb window list --app "$APP_BUNDLE_ID" --json)"
  window_id="$(echo "$windows_json" | jq -r --arg title "$title" '.data.windows[] | select(.window_title == $title and .is_on_screen == true) | .window_id' | head -n1)"

  if [ -z "$window_id" ]; then
    echo "Could not find on-screen window with title: $title"
    exit 4
  fi

  echo "$window_id"
}

require_command peekaboo
require_command rg
require_command jq

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle not found at: $APP_PATH"
  echo "Build it first with: ./BUILD_DOCK_APP.command"
  exit 1
fi

PERMISSIONS_OUTPUT="$(pb list permissions)"
if echo "$PERMISSIONS_OUTPUT" | rg -q "Not Granted"; then
  echo "$PERMISSIONS_OUTPUT"
  echo
  echo "Peekaboo requires both permissions before capture:"
  echo "  1) System Settings > Privacy & Security > Screen & System Audio Recording"
  echo "  2) System Settings > Privacy & Security > Accessibility"
  echo "Enable your terminal app, then rerun this script."
  exit 2
fi

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/main.png" "$OUT_DIR/statistics.png"

pb open "$APP_PATH" --wait-until-ready
pb sleep 1200

# Main window (default width target).
pb app switch --to "$APP_NAME"
pb window set-bounds --app "$APP_BUNDLE_ID" --x 110 --y 70 --width 620 --height 760
pb sleep 500
MAIN_WINDOW_ID="$(window_id_for_title "Dual N-Back")"
pb image --window-id "$MAIN_WINDOW_ID" --mode window --retina --path "$OUT_DIR/main.png"

# Statistics window.
pb app switch --to "$APP_NAME"
click_actionable_label "Statistics"
pb sleep 800
pb window set-bounds --app "$APP_BUNDLE_ID" --window-title "Statistics" --x 180 --y 90 --width 900 --height 640
pb sleep 500
STATS_WINDOW_ID="$(window_id_for_title "Statistics")"
pb image --window-id "$STATS_WINDOW_ID" --mode window --retina --path "$OUT_DIR/statistics.png"
pb hotkey --keys "cmd,w" --app "$APP_BUNDLE_ID" --window-title "Statistics"
pb sleep 300

echo "Saved screenshots to: $OUT_DIR"
