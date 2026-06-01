#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/Tangle.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

rm -rf "$DIST_DIR" "$BUILD_DIR/package"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$BUILD_DIR/package"

swift build -c release --product TangleGUI
swift build -c release --product tangle

if [ ! -f "$BUILD_DIR/AppIcon.icns" ]; then
  scripts/generate-app-icon.swift
fi

cp ".build/release/TangleGUI" "$MACOS_DIR/TangleGUI"
cp ".build/release/tangle" "$RESOURCES_DIR/tangle"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

chmod +x "$MACOS_DIR/TangleGUI"
chmod +x "$RESOURCES_DIR/tangle"

plutil -lint "$CONTENTS_DIR/Info.plist"

ditto -c -k --keepParent "$APP_DIR" "$DIST_DIR/Tangle.zip"
hdiutil create \
  -volname "Tangle" \
  -srcfolder "$APP_DIR" \
  -ov \
  -format UDZO \
  "$DIST_DIR/Tangle.dmg"

echo "Created:"
echo "  $APP_DIR"
echo "  $DIST_DIR/Tangle.zip"
echo "  $DIST_DIR/Tangle.dmg"
