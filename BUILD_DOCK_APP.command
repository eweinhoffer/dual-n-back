#!/bin/zsh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$REPO_DIR/SwiftDualNBackPrototype"
BUILD_DIR="$PROJECT_DIR/Build"
SOURCE_APP="$BUILD_DIR/Build/Products/Release/Dual N-Back.app"
OUTPUT_APP="$REPO_DIR/Dual N-Back.app"
CHECK_SCRIPT="$REPO_DIR/scripts/check_build_env.sh"
ASSET_ICON_DIR="$PROJECT_DIR/Sources/SwiftDualNBackPrototype/Assets.xcassets/AppIcon.appiconset"
SWIFTPM_PRODUCT_NAME="SwiftDualNBackPrototype"

make_app_icon() {
  local output_icns="$1"
  local temp_tiff
  temp_tiff="$(mktemp /tmp/dual-n-back-icon.XXXXXX.tiff)"

  tiffutil -cat \
    "$ASSET_ICON_DIR/icon_16x16.png" \
    "$ASSET_ICON_DIR/icon_32x32.png" \
    "$ASSET_ICON_DIR/icon_128x128.png" \
    "$ASSET_ICON_DIR/icon_256x256.png" \
    "$ASSET_ICON_DIR/icon_512x512.png" \
    "$ASSET_ICON_DIR/icon_1024x1024.png" \
    -out "$temp_tiff" >/dev/null

  tiff2icns "$temp_tiff" "$output_icns" >/dev/null
  rm -f "$temp_tiff"
}

write_manual_info_plist() {
  local plist_path="$1"
  /bin/cat > "$plist_path" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Dual N-Back</string>
    <key>CFBundleExecutable</key>
    <string>Dual N-Back</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>io.dualnback.SwiftDualNBackPrototype</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Dual N-Back</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST
}

package_swiftpm_app() {
  local bin_dir
  local source_binary

  echo "Falling back to SwiftPM app packaging..."
  (
    cd "$PROJECT_DIR"
    swift build -c release
    bin_dir="$(swift build -c release --show-bin-path)"
    source_binary="$bin_dir/$SWIFTPM_PRODUCT_NAME"

    if [[ ! -f "$source_binary" ]]; then
      echo "ERROR: SwiftPM build completed but the executable was not found:"
      echo "  $source_binary"
      exit 1
    fi

    rm -rf "$OUTPUT_APP"
    mkdir -p "$OUTPUT_APP/Contents/MacOS" "$OUTPUT_APP/Contents/Resources"

    ditto "$source_binary" "$OUTPUT_APP/Contents/MacOS/Dual N-Back"
    chmod +x "$OUTPUT_APP/Contents/MacOS/Dual N-Back"

    write_manual_info_plist "$OUTPUT_APP/Contents/Info.plist"
    make_app_icon "$OUTPUT_APP/Contents/Resources/AppIcon.icns"

    codesign --force --sign - "$OUTPUT_APP" >/dev/null
  )
}

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
  build || package_swiftpm_app

if [[ -d "$SOURCE_APP" ]]; then
  echo "Refreshing app bundle at $OUTPUT_APP"
  rm -rf "$OUTPUT_APP"
  ditto "$SOURCE_APP" "$OUTPUT_APP"
elif [[ ! -d "$OUTPUT_APP" ]]; then
  echo "ERROR: neither the Xcode build nor the SwiftPM fallback produced an app bundle."
  exit 1
fi

echo "Done."
echo "App path: $OUTPUT_APP"
echo "Next step: drag Dual N-Back.app into your Dock."
