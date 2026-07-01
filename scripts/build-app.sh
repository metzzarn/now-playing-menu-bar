#!/bin/bash
#
# Builds a distributable NowPlayingBar.app bundle from the SPM release binary.
#
# Usage:
#   scripts/build-app.sh                 # ad-hoc signed (re-prompts Keychain per rebuild)
#   SIGN_IDENTITY="Apple Development" scripts/build-app.sh   # stable signing
#
set -euo pipefail

APP_NAME="NowPlayingBar"
BUNDLE_ID="com.nowplayingbar.app"
VERSION="0.5.0"                 # keep in sync with CHANGELOG.md
MIN_MACOS="13.0"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # "-" means ad-hoc

cd "$(dirname "$0")/.."

echo "Building release binary"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

APP="build/$APP_NAME.app"
echo "Assembling ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>NowPlayingBar</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string></string>
</dict>
</plist>
PLIST

echo "Signing (${SIGN_IDENTITY})"
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP"

echo "Done: $APP"
echo "Install by dragging it to /Applications (or: cp -R \"$APP\" /Applications/)."
