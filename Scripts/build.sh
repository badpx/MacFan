#!/bin/bash
# Builds MacFan.app: release compile -> bundle -> ad-hoc codesign.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MacFan"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "==> Compiling (release)"
swift build -c release --arch arm64

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$(swift build -c release --arch arm64 --show-bin-path)/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

echo "==> Ad-hoc code signing (required for launch-at-login)"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Done: $APP_DIR"
echo "    Install: cp -R $APP_DIR /Applications/"
