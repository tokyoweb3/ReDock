#!/bin/bash
# Build a release .app bundle and create a DMG for distribution.
# Usage: bash scripts/release.sh [version]
# Example: bash scripts/release.sh 2.0.0
set -euo pipefail

VERSION="${1:-2.0.0}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MWM"
BUILD_DIR="$PROJECT_DIR/build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
DMG_NAME="MWM-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "=== MWM Release Build v${VERSION} ==="

# 1. Run tests
echo ""
echo "[1/6] Running tests..."
cd "$PROJECT_DIR"
swift test --parallel
echo "All tests passed."

# 2. Release build
echo ""
echo "[2/6] Building release binary..."
swift build -c release

# 3. Create .app bundle
echo ""
echo "[3/6] Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

cp ".build/release/$APP_NAME" "$MACOS/$APP_NAME"
strip "$MACOS/$APP_NAME"

# Generate app icon
ICNS="$RESOURCES/AppIcon.icns"
echo "Generating app icon..."
swift "$PROJECT_DIR/scripts/generate_icon.swift" "$PROJECT_DIR"
iconutil -c icns "$PROJECT_DIR/build/MWM.iconset" -o "$ICNS"
rm -rf "$PROJECT_DIR/build/MWM.iconset"

# Copy SPM resource bundles
for bundle in .build/release/*.bundle; do
    if [ -d "$bundle" ]; then
        cp -R "$bundle" "$RESOURCES/"
    fi
done

cat > "$CONTENTS/Info.plist" << PLIST
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
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024-2026 MWM. All rights reserved.</string>
</dict>
</plist>
PLIST

# 4. Code sign
echo ""
echo "[4/6] Code signing..."
codesign --force --sign - --deep "$APP_BUNDLE"

# 5. Create DMG
echo ""
echo "[5/6] Creating DMG..."
rm -f "$DMG_PATH"

DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "MWM ${VERSION}" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING"

# 6. Summary
echo ""
echo "[6/6] Release build complete!"
echo ""
echo "  App:     $APP_BUNDLE"
echo "  DMG:     $DMG_PATH"
echo "  Version: ${VERSION}"
echo ""

# Print binary size
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
echo "  App size: ${APP_SIZE}"
echo "  DMG size: ${DMG_SIZE}"
echo ""
echo "To install: open '$DMG_PATH' and drag MWM to Applications"
echo ""
echo "To create a GitHub release:"
echo "  git tag v${VERSION}"
echo "  git push origin v${VERSION}"
echo "  gh release create v${VERSION} '$DMG_PATH' --title 'MWM v${VERSION}' --notes-file CHANGELOG.md"
