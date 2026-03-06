#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="eweinhoffer/dual-n-back"
APP_NAME="Dual N-Back.app"
APP_EXECUTABLE="Dual N-Back"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/update_from_github.sh [tag]

Examples:
  ./scripts/update_from_github.sh
  ./scripts/update_from_github.sh v1.2.3

Environment variables:
  INSTALL_DIR   Override install location. Defaults to /Applications when writable,
                otherwise falls back to ~/Applications.
EOF
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
}

detect_arch() {
  local machine_arch
  machine_arch="$(uname -m)"

  case "$machine_arch" in
    arm64|x86_64)
      echo "$machine_arch"
      ;;
    *)
      echo "Unsupported architecture: $machine_arch"
      exit 1
      ;;
  esac
}

resolve_install_dir() {
  if [[ -n "${INSTALL_DIR:-}" ]]; then
    echo "$INSTALL_DIR"
    return
  fi

  if [[ -d "/Applications" && -w "/Applications" ]]; then
    echo "/Applications"
    return
  fi

  if [[ -d "/Applications/$APP_NAME" ]]; then
    echo "/Applications"
    return
  fi

  echo "$HOME/Applications"
}

ensure_app_not_running() {
  if pgrep -x "$APP_EXECUTABLE" >/dev/null 2>&1 || pgrep -f "${APP_NAME}/Contents/MacOS/${APP_EXECUTABLE}" >/dev/null 2>&1; then
    echo "Please quit $APP_NAME before updating."
    exit 1
  fi
}

fetch_release_json() {
  local tag_name="${1:-}"
  local api_url

  if [[ -n "$tag_name" ]]; then
    api_url="https://api.github.com/repos/${REPO_SLUG}/releases/tags/${tag_name}"
  else
    api_url="https://api.github.com/repos/${REPO_SLUG}/releases/latest"
  fi

  curl --fail --silent --show-error --location "$api_url"
}

download_asset() {
  local url="$1"
  local output_path="$2"
  curl --fail --silent --show-error --location "$url" --output "$output_path"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

TAG_OVERRIDE="${1:-}"

require_command curl
require_command jq
require_command shasum
require_command unzip
require_command ditto

ARCH="$(detect_arch)"
INSTALL_PATH="$(resolve_install_dir)"
TEMP_DIR="$(mktemp -d)"
BACKUP_PATH="$TEMP_DIR/${APP_NAME}.backup"
ROLLBACK_READY=0
UPDATE_COMPLETE=0

cleanup() {
  if [[ "$UPDATE_COMPLETE" -ne 1 && "$ROLLBACK_READY" -eq 1 ]]; then
    echo "Update failed. Restoring previous app bundle..."
    rm -rf "$INSTALL_PATH/$APP_NAME"
    ditto "$BACKUP_PATH" "$INSTALL_PATH/$APP_NAME"
  fi

  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT INT TERM

ensure_app_not_running
mkdir -p "$INSTALL_PATH"

echo "Fetching release metadata from GitHub..."
RELEASE_JSON="$(fetch_release_json "$TAG_OVERRIDE")"
TAG_NAME="$(echo "$RELEASE_JSON" | jq -r '.tag_name')"
if [[ -z "$TAG_NAME" || "$TAG_NAME" == "null" ]]; then
  echo "Could not determine release tag from GitHub response."
  exit 1
fi

ZIP_NAME="Dual-N-Back-macOS-unsigned-${ARCH}.zip"
ZIP_URL="$(echo "$RELEASE_JSON" | jq -r --arg name "$ZIP_NAME" '.assets[] | select(.name == $name) | .browser_download_url')"
SUMS_URL="$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name == "SHA256SUMS.txt") | .browser_download_url')"
SIG_URL="$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name == "SHA256SUMS.txt.sig") | .browser_download_url')"
PUBKEY_URL="$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name == "release-signing-public.pem") | .browser_download_url')"

if [[ -z "$ZIP_URL" || "$ZIP_URL" == "null" ]]; then
  echo "Release $TAG_NAME does not contain expected asset: $ZIP_NAME"
  exit 1
fi

if [[ -z "$SUMS_URL" || "$SUMS_URL" == "null" ]]; then
  echo "Release $TAG_NAME is missing SHA256SUMS.txt"
  exit 1
fi

echo "Downloading $ZIP_NAME for $ARCH..."
download_asset "$ZIP_URL" "$TEMP_DIR/$ZIP_NAME"
download_asset "$SUMS_URL" "$TEMP_DIR/SHA256SUMS.txt"

if [[ -n "$SIG_URL" && "$SIG_URL" != "null" && -n "$PUBKEY_URL" && "$PUBKEY_URL" != "null" ]]; then
  require_command openssl
  download_asset "$SIG_URL" "$TEMP_DIR/SHA256SUMS.txt.sig"
  download_asset "$PUBKEY_URL" "$TEMP_DIR/release-signing-public.pem"
fi

echo "Verifying checksum..."
(
  cd "$TEMP_DIR"
  shasum -a 256 -c SHA256SUMS.txt --ignore-missing
)

if [[ -f "$TEMP_DIR/SHA256SUMS.txt.sig" && -f "$TEMP_DIR/release-signing-public.pem" ]]; then
  echo "Verifying signature..."
  openssl dgst -sha256 \
    -verify "$TEMP_DIR/release-signing-public.pem" \
    -signature "$TEMP_DIR/SHA256SUMS.txt.sig" \
    "$TEMP_DIR/SHA256SUMS.txt"
else
  echo "Signature assets not present for $TAG_NAME. Continuing with checksum verification only."
fi

echo "Unpacking app bundle..."
unzip -q "$TEMP_DIR/$ZIP_NAME" -d "$TEMP_DIR/unpacked"

if [[ ! -d "$TEMP_DIR/unpacked/$APP_NAME" ]]; then
  echo "Downloaded archive did not contain $APP_NAME"
  exit 1
fi

if [[ -d "$INSTALL_PATH/$APP_NAME" ]]; then
  echo "Backing up current installation from $INSTALL_PATH..."
  ditto "$INSTALL_PATH/$APP_NAME" "$BACKUP_PATH"
  ROLLBACK_READY=1
fi

echo "Installing $APP_NAME to $INSTALL_PATH..."
rm -rf "$INSTALL_PATH/$APP_NAME"
ditto "$TEMP_DIR/unpacked/$APP_NAME" "$INSTALL_PATH/$APP_NAME"
UPDATE_COMPLETE=1

echo "Update complete."
echo "Installed $APP_NAME from release $TAG_NAME to $INSTALL_PATH"
