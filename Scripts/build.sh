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
    # --build-system native: the default SwiftBuild backend fails on this
    # toolchain ("no extensions provided a fallback value" for the dev dir).
    swift build -c release --arch "$arch" --build-system native
    BINARIES+=("$(swift build -c release --arch "$arch" --build-system native --show-bin-path)/$APP_NAME")
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
# Explicit flat Icon Composer artwork prevents macOS 26 from automatically
# embossing the legacy ICNS. Keep our hand-rendered ICNS for macOS 13–15.
echo "==> Compiling flat application icon (Xcode 26+)"
xcrun actool Resources/MacFanFlat.icon \
    --compile "$APP_DIR/Contents/Resources" \
    --app-icon MacFanFlat --platform macosx --target-device mac \
    --minimum-deployment-target 13.0 --development-region zh_CN \
    --enable-on-demand-resources NO \
    --enable-icon-stack-fallback-generation=disabled \
    --include-all-app-icons \
    --output-partial-info-plist "$BUILD_DIR/icon-info.plist"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconFile' "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Merge build/icon-info.plist' "$APP_DIR/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/MacFanFlat.icns"
cp Resources/MenuEyeOn.png Resources/MenuEyeOff.png "$APP_DIR/Contents/Resources/"

echo "==> Ad-hoc code signing (required for launch-at-login)"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Done: $APP_DIR"
echo "    Install: cp -R $APP_DIR /Applications/"
