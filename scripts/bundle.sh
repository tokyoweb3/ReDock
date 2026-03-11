#!/bin/bash
# Build and create a minimal .app bundle for ReDock
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ReDock"
APP_BUNDLE="$PROJECT_DIR/build/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building..."
cd "$PROJECT_DIR"
swift build -c debug

echo "Creating .app bundle..."
mkdir -p "$MACOS" "$RESOURCES"

# Symlink to the build binary so the .app shares the same TCC (Accessibility)
# permission as the direct binary. Copying creates a separate identity that
# macOS tracks independently, causing permission mismatches.
ln -sf "$PROJECT_DIR/.build/debug/$APP_NAME" "$MACOS/$APP_NAME"

# Generate app icon
ICNS="$RESOURCES/AppIcon.icns"
ICON_SCRIPT="$PROJECT_DIR/scripts/generate_icon.swift"
if [ ! -f "$ICNS" ] || [ "$ICON_SCRIPT" -nt "$ICNS" ]; then
    echo "Generating app icon..."
    swift "$ICON_SCRIPT" "$PROJECT_DIR"
    iconutil -c icns "$PROJECT_DIR/build/ReDock.iconset" -o "$ICNS"
    rm -rf "$PROJECT_DIR/build/ReDock.iconset"
fi

cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.ReDock.app</string>
    <key>CFBundleName</key>
    <string>ReDock</string>
    <key>CFBundleDisplayName</key>
    <string>ReDock</string>
    <key>CFBundleExecutable</key>
    <string>ReDock</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

# Skip codesigning for debug builds to preserve macOS TCC permissions.
# Each ad-hoc codesign generates a new cdHash, invalidating Accessibility grants.
# The binary already has an ad-hoc signature from swift build.
# For release builds, use scripts/release.sh which signs properly.
echo "Skipping codesign (debug build) to preserve Accessibility permissions."

echo "Done: $APP_BUNDLE"
echo ""
echo "To run: open '$APP_BUNDLE'"
echo "To stop: pkill -f ReDock.app"
