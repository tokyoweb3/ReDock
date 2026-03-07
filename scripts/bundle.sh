#!/bin/bash
# Build and create a minimal .app bundle for MWM
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MWM"
APP_BUNDLE="$PROJECT_DIR/build/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building..."
cd "$PROJECT_DIR"
swift build -c debug

echo "Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

cp ".build/debug/$APP_NAME" "$MACOS/$APP_NAME"

# Generate app icon
ICNS="$RESOURCES/AppIcon.icns"
if [ ! -f "$ICNS" ] || [ "$0" -nt "$ICNS" ]; then
    echo "Generating app icon..."
    swift "$PROJECT_DIR/scripts/generate_icon.swift" "$PROJECT_DIR"
    iconutil -c icns "$PROJECT_DIR/build/MWM.iconset" -o "$ICNS"
    rm -rf "$PROJECT_DIR/build/MWM.iconset"
fi

cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.mwm.app</string>
    <key>CFBundleName</key>
    <string>MWM</string>
    <key>CFBundleDisplayName</key>
    <string>MWM</string>
    <key>CFBundleExecutable</key>
    <string>MWM</string>
    <key>CFBundleVersion</key>
    <string>2.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
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

echo "Signing with ad-hoc identity..."
codesign --force --sign - "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"
echo ""
echo "To run: open '$APP_BUNDLE'"
echo "To stop: pkill -f MWM.app"
