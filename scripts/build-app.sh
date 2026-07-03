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
VERSION="0.16.0"                # keep in sync with CHANGELOG.md
MIN_MACOS="13.0"
ICON_SRC="icons"
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

echo "Building app icon"
# iconutil rejects the source PNGs' embedded color profile, so re-encode each
# through sips into a fresh .iconset with the names iconutil expects.
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
enc() { sips -s format png -z "$2" "$2" "$ICON_SRC/$1" --out "$ICONSET/$3" >/dev/null; }
enc 16-mac.png   16   icon_16x16.png
enc 32-mac.png   32   icon_16x16@2x.png
enc 32-mac.png   32   icon_32x32.png
enc 64-mac.png   64   icon_32x32@2x.png
enc 128-mac.png  128  icon_128x128.png
enc 256-mac.png  256  icon_128x128@2x.png
enc 256-mac.png  256  icon_256x256.png
enc 512-mac.png  512  icon_256x256@2x.png
enc 512-mac.png  512  icon_512x512.png
enc 1024-mac.png 1024 icon_512x512@2x.png
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>NowPlayingBar</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
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
