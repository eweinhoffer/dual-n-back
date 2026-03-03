#!/bin/zsh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$REPO_DIR/SwiftDualNBackPrototype"
BUILD_DIR="$PROJECT_DIR/Build"
SOURCE_APP="$BUILD_DIR/Build/Products/Release/Dual N-Back.app"
OUTPUT_APP="$REPO_DIR/Dual N-Back.app"
CHECK_SCRIPT="$REPO_DIR/scripts/check_build_env.sh"

echo "Running build environment checks..."
if [[ ! -x "$CHECK_SCRIPT" ]]; then
  echo "ERROR: missing executable check script at:"
  echo "  $CHECK_SCRIPT"
  echo "Fix: run 'chmod +x scripts/check_build_env.sh' and retry."
  exit 1
fi
"$CHECK_SCRIPT"

echo "Building Release app with Xcode..."
xcodebuild \
  -project "$PROJECT_DIR/SwiftDualNBackPrototype.xcodeproj" \
  -scheme SwiftDualNBackPrototype \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  build

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "ERROR: build finished but expected app bundle was not found:"
  echo "  $SOURCE_APP"
  echo "Fix: open the project in Xcode and confirm the scheme builds for macOS."
  exit 1
fi

echo "Refreshing app bundle at $OUTPUT_APP"
rm -rf "$OUTPUT_APP"
ditto "$SOURCE_APP" "$OUTPUT_APP"

echo "Done."
echo "App path: $OUTPUT_APP"
echo "Next step: drag Dual N-Back.app into your Dock."
