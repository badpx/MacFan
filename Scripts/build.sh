#!/bin/bash
# Builds MacFan.app: release compile -> bundle -> ad-hoc codesign.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MacFan"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "==> Compiling (release, per-arch)"
BINARIES=()
for arch in arm64 x86_64; do
    swift build -c release --arch "$arch"
    BINARIES+=("$(swift build -c release --arch "$arch" --show-bin-path)/$APP_NAME")
done

echo "==> Creating universal binary"
UNIVERSAL="$BUILD_DIR/$APP_NAME-universal"
mkdir -p "$BUILD_DIR"
lipo -create "${BINARIES[@]}" -output "$UNIVERSAL"

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$UNIVERSAL" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "==> Ad-hoc code signing (required for launch-at-login)"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Done: $APP_DIR"
echo "    Install: cp -R $APP_DIR /Applications/"
