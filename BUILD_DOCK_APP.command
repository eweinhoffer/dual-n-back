#!/bin/zsh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$REPO_DIR/SwiftDualNBackPrototype"
BUILD_DIR="$PROJECT_DIR/Build"
SOURCE_APP="$BUILD_DIR/Build/Products/Release/Dual N-Back.app"
OUTPUT_APP="$REPO_DIR/Dual N-Back.app"

echo "Building Release app with Xcode..."
xcodebuild \
  -project "$PROJECT_DIR/SwiftDualNBackPrototype.xcodeproj" \
  -scheme SwiftDualNBackPrototype \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build

echo "Refreshing app bundle at $OUTPUT_APP"
rm -rf "$OUTPUT_APP"
cp -R "$SOURCE_APP" "$OUTPUT_APP"

echo "Done."
echo "App path: $OUTPUT_APP"
echo "Next step: drag Dual N-Back.app into your Dock."
