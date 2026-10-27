#!/bin/bash
# MenuGauge packaging. SwiftPM + a hand-assembled .app. No Xcode project.
#
#   Scripts/build.sh                  local ad-hoc MenuGauge.app (unchanged flow)
#   Scripts/build.sh dmg              Developer ID, notarized, stapled DMG
#   Scripts/build.sh appstore         sandboxed Mac App Store pkg
#   Scripts/build.sh appstore --upload
#
# Identities, team ID, profile, version and notarization credentials come
# from the environment or flags. API keys are file paths, never key material
# on the command line. Full steps: docs/Release.md
#
# bash 3.2 compatible (the bash that ships with macOS).
set -euo pipefail

CALLER_PWD=$PWD
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

APP_NAME="MenuGauge"
BUILD_DIR="build"
MACFAN_KEY_DIR=""

cleanup() {
  if [[ -n "$MACFAN_KEY_DIR" && -d "$MACFAN_KEY_DIR" ]]; then
    rm -rf "$MACFAN_KEY_DIR"
  fi
}
trap cleanup EXIT

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  Scripts/build.sh [app] [flags]     ad-hoc universal MenuGauge.app
  Scripts/build.sh dmg [flags]       Developer ID disk image, notarized
  Scripts/build.sh appstore [flags]  sandboxed Mac App Store package
  Scripts/build.sh --help

Flags (override the same environment variable):
  --version VER              MACFAN_VERSION (major.minor.patch)
  --build N                  MACFAN_BUILD (integer CFBundleVersion)
  --bundle-id ID             MACFAN_BUNDLE_ID (default com.badpx.macfan)
  --developer-id NAME        DEVELOPER_ID_APPLICATION
  --distribution-identity N  APPLE_DISTRIBUTION_IDENTITY
  --installer-identity NAME  MAC_INSTALLER_DISTRIBUTION_IDENTITY
  --team-id TEAM             APPLE_TEAM_ID
  --profile PATH             MACFAN_PROVISIONING_PROFILE
  --keychain PATH            MACFAN_KEYCHAIN
  --notary-profile NAME      NOTARY_KEYCHAIN_PROFILE
  --notary-key PATH          NOTARY_KEY_PATH (.p8 file)
  --notary-key-id ID         NOTARY_KEY_ID
  --notary-issuer UUID       NOTARY_ISSUER
  --asc-key PATH             ASC_KEY_PATH (.p8 file, upload only)
  --asc-key-id ID            ASC_KEY_ID
  --asc-issuer UUID          ASC_ISSUER_ID
  --asc-app-id ID            ASC_APP_APPLE_ID (numeric App Store Connect id)
  --asc-public-id ID         ASC_PUBLIC_ID (only if the account has several providers)
  --upload                   MACFAN_UPLOAD=1 (appstore only; off by default)

dmg and appstore require --version and --build (or the env vars).
The local app command defaults to 1.0.0 (1) when they are omitted.
Notarization uses the API key when NOTARY_KEY_PATH, NOTARY_KEY_ID and
NOTARY_ISSUER are all set; otherwise NOTARY_KEYCHAIN_PROFILE.
See docs/Release.md for certificates, the profile, and App Store Connect.
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "required command not found: $1"
  fi
}

# Resolves a user-supplied path against the caller's working directory.
# Sets RESOLVED_PATH. Dies in this shell (not a command substitution),
# which bash 3.2 would otherwise swallow under `set -e`.
resolve_existing_file() {
  local label="$1"
  local raw="$2"
  case "$raw" in
    /*) RESOLVED_PATH=$raw ;;
    *) RESOLVED_PATH="$CALLER_PWD/$raw" ;;
  esac
  if [[ ! -f "$RESOLVED_PATH" ]]; then
    die "$label not found: $RESOLVED_PATH"
  fi
}

# Sets FLAG_VALUE. `count` is the caller's remaining "$#".
flag_value() {
  local flag="$1"
  local count="$2"
  local value="${3:-}"
  if [[ "$count" -lt 2 || -z "$value" ]]; then
    die "$flag needs a value"
  fi
  FLAG_VALUE=$value
}

COMMAND="app"
if [[ $# -gt 0 ]]; then
  case "$1" in
    app|dmg|appstore)
      COMMAND="$1"
      shift
      ;;
    help|-h|--help)
      usage
      exit 0
      ;;
  esac
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      flag_value "$1" "$#" "${2:-}"
      MACFAN_VERSION=$FLAG_VALUE
      shift 2
      ;;
    --build)
      flag_value "$1" "$#" "${2:-}"
      MACFAN_BUILD=$FLAG_VALUE
      shift 2
      ;;
    --bundle-id)
      flag_value "$1" "$#" "${2:-}"
      MACFAN_BUNDLE_ID=$FLAG_VALUE
      shift 2
      ;;
    --developer-id)
      flag_value "$1" "$#" "${2:-}"
      DEVELOPER_ID_APPLICATION=$FLAG_VALUE
      shift 2
      ;;
    --distribution-identity)
      flag_value "$1" "$#" "${2:-}"
      APPLE_DISTRIBUTION_IDENTITY=$FLAG_VALUE
      shift 2
      ;;
    --installer-identity)
      flag_value "$1" "$#" "${2:-}"
      MAC_INSTALLER_DISTRIBUTION_IDENTITY=$FLAG_VALUE
      shift 2
      ;;
    --team-id)
      flag_value "$1" "$#" "${2:-}"
      APPLE_TEAM_ID=$FLAG_VALUE
      shift 2
      ;;
    --profile)
      flag_value "$1" "$#" "${2:-}"
      MACFAN_PROVISIONING_PROFILE=$FLAG_VALUE
      shift 2
      ;;
    --keychain)
      flag_value "$1" "$#" "${2:-}"
      MACFAN_KEYCHAIN=$FLAG_VALUE
      shift 2
      ;;
    --notary-profile)
      flag_value "$1" "$#" "${2:-}"
      NOTARY_KEYCHAIN_PROFILE=$FLAG_VALUE
      shift 2
      ;;
    --notary-key)
      flag_value "$1" "$#" "${2:-}"
      NOTARY_KEY_PATH=$FLAG_VALUE
      shift 2
      ;;
    --notary-key-id)
      flag_value "$1" "$#" "${2:-}"
      NOTARY_KEY_ID=$FLAG_VALUE
      shift 2
      ;;
    --notary-issuer)
      flag_value "$1" "$#" "${2:-}"
      NOTARY_ISSUER=$FLAG_VALUE
      shift 2
      ;;
    --asc-key)
      flag_value "$1" "$#" "${2:-}"
      ASC_KEY_PATH=$FLAG_VALUE
      shift 2
      ;;
    --asc-key-id)
      flag_value "$1" "$#" "${2:-}"
      ASC_KEY_ID=$FLAG_VALUE
      shift 2
      ;;
    --asc-issuer)
      flag_value "$1" "$#" "${2:-}"
      ASC_ISSUER_ID=$FLAG_VALUE
      shift 2
      ;;
    --asc-app-id)
      flag_value "$1" "$#" "${2:-}"
      ASC_APP_APPLE_ID=$FLAG_VALUE
      shift 2
      ;;
    --asc-public-id)
      flag_value "$1" "$#" "${2:-}"
      ASC_PUBLIC_ID=$FLAG_VALUE
      shift 2
      ;;
    --upload)
      MACFAN_UPLOAD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1 (see Scripts/build.sh --help)"
      ;;
  esac
done

case "${MACFAN_UPLOAD:-0}" in
  1|true|TRUE|yes|YES) MACFAN_UPLOAD=1 ;;
  0|false|FALSE|no|NO) MACFAN_UPLOAD=0 ;;
  *) die "MACFAN_UPLOAD must be 1 or 0" ;;
esac

if [[ "$MACFAN_UPLOAD" -eq 1 && "$COMMAND" != "appstore" ]]; then
  die "--upload is only valid with: Scripts/build.sh appstore --upload"
fi

: "${MACFAN_BUNDLE_ID:=com.badpx.macfan}"
BUNDLE_ID=$MACFAN_BUNDLE_ID
if [[ ! "$BUNDLE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[.][A-Za-z0-9.-]+$ ]]; then
  die "MACFAN_BUNDLE_ID must be a reverse-DNS id (got: $BUNDLE_ID)"
fi

if [[ "$COMMAND" == "app" ]]; then
  : "${MACFAN_VERSION:=1.0.0}"
  : "${MACFAN_BUILD:=1}"
else
  if [[ -z "${MACFAN_VERSION:-}" || -z "${MACFAN_BUILD:-}" ]]; then
    die "$COMMAND requires MACFAN_VERSION (1.2.3) and MACFAN_BUILD (integer), via env or --version/--build"
  fi
fi

if [[ ! "$MACFAN_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  die "MACFAN_VERSION must be major.minor.patch (got: $MACFAN_VERSION)"
fi
# App Store Connect compares CFBundleVersion numerically. Leading zeros
# would sort as a different string, so reject them except for a plain 0.
if [[ ! "$MACFAN_BUILD" =~ ^(0|[1-9][0-9]*)$ ]]; then
  die "MACFAN_BUILD must be a non-negative integer without leading zeros (got: $MACFAN_BUILD)"
fi

SWIFT_SCRATCH_FLAG=""
detect_scratch_flag() {
  local help status=0
  help=$(swift build --help 2>&1) || status=$?
  if [[ "$status" -ne 0 ]]; then
    die "swift build --help failed (exit $status)"
  fi
  # Match in the shell. A pipeline into grep -q exits 141 under pipefail
  # when grep stops at the first hit and the producer gets SIGPIPE.
  if [[ "$help" == *'--scratch-path'* ]]; then
    SWIFT_SCRATCH_FLAG="--scratch-path"
  elif [[ "$help" == *'--build-path'* ]]; then
    SWIFT_SCRATCH_FLAG="--build-path"
  else
    die "swift build has neither --scratch-path nor --build-path"
  fi
}

# Distinct scratch directories: -DMAS must not reuse the direct edition's
# object files, and the other way around.
compile_release() {
  local edition="$1"
  local scratch="$ROOT/$BUILD_DIR/spm-$edition"
  local universal="$ROOT/$BUILD_DIR/$APP_NAME-$edition-universal"
  local arch bin_dir
  local -a binaries swift_args
  binaries=()
  detect_scratch_flag
  echo "==> Compiling (release, per-arch, $edition)"
  for arch in arm64 x86_64; do
    swift_args=(swift build -c release --arch "$arch" --build-system native "$SWIFT_SCRATCH_FLAG" "$scratch")
    if [[ "$edition" == "mas" ]]; then
      swift_args+=(-Xswiftc -DMAS)
    fi
    "${swift_args[@]}"
    if ! bin_dir=$("${swift_args[@]}" --show-bin-path); then
      die "swift build --show-bin-path failed for $arch"
    fi
    binaries+=("$bin_dir/$APP_NAME")
  done
  echo "==> Creating universal binary"
  mkdir -p "$BUILD_DIR"
  lipo -create "${binaries[@]}" -output "$universal"
  assert_edition_symbols "$edition" "$universal"
  UNIVERSAL_BIN=$universal
}

# 0 when the slice's nm listing contains the symbol, 1 when it does not.
# nm itself failing is fatal: swallowing that used to look like "not
# imported", so the App Store check would accept a binary it could not read.
slice_imports() {
  local file="$1"
  local arch="$2"
  local symbol="$3"
  local symbols status=0
  symbols=$(nm -arch "$arch" "$file") || status=$?
  if [[ "$status" -ne 0 ]]; then
    die "nm failed for $arch slice of $file (exit $status)"
  fi
  # grep -c reads all of its input. grep -q in a pipeline does not: it
  # exits at the first hit, nm dies with SIGPIPE, and pipefail turns a
  # real import into status 141. That failed the direct-edition check
  # and let the MAS check pass while the symbol was present.
  local count=0
  status=0
  count=$(printf '%s\n' "$symbols" | grep -F -c -- "$symbol") || status=$?
  if [[ "$status" -gt 1 ]]; then
    die "could not scan nm output for $symbol (exit $status)"
  fi
  [[ "${count:-0}" -gt 0 ]]
}

# UTF-8 or UTF-16LE, so a Swift string literal cannot hide from the check.
binary_contains() {
  local file="$1"
  local needle="$2"
  local status=0
  perl -MEncode -0777 -e '
    my ($path, $needle) = @ARGV;
    open my $fh, "<:raw", $path or die "open failed\n";
    local $/;
    my $data = <$fh>;
    close $fh;
    my $utf16 = Encode::encode("UTF-16LE", $needle);
    if (index($data, $needle) >= 0 || index($data, $utf16) >= 0) { exit 0; }
    exit 1;
  ' "$file" "$needle" || status=$?
  if [[ "$status" -eq 0 ]]; then
    return 0
  elif [[ "$status" -eq 1 ]]; then
    return 1
  fi
  die "could not scan $file (perl exit $status)"
}

assert_edition_symbols() {
  local edition="$1"
  local file="$2"
  local arch
  if binary_contains "$file" "IOHIDEventSystemClientCreate"; then
    die "$edition binary still references private IOHIDEventSystemClientCreate"
  fi
  for arch in arm64 x86_64; do
    if [[ "$edition" == "mas" ]]; then
      if slice_imports "$file" "$arch" "_IOServiceOpen"; then
        die "MAS $arch slice still references _IOServiceOpen; AppleSMC was not compiled out"
      fi
    else
      if ! slice_imports "$file" "$arch" "_IOServiceOpen"; then
        die "direct $arch slice does not reference _IOServiceOpen; SMC was compiled out by mistake"
      fi
    fi
  done
  if [[ "$edition" == "mas" ]]; then
    if binary_contains "$file" "AppleSMC"; then
      die "MAS binary still contains the AppleSMC literal"
    fi
  elif ! binary_contains "$file" "AppleSMC"; then
    die "direct binary is missing the AppleSMC literal"
  fi
}

plist_set_string() {
  local plist="$1"
  local key="$2"
  local value="$3"
  if /usr/libexec/PlistBuddy -c "Print :$key" "$plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist"
  else
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist"
  fi
}

assemble_app() {
  local dest="$1"
  echo "==> Assembling $dest"
  rm -rf "$dest"
  mkdir -p "$dest/Contents/MacOS" "$dest/Contents/Resources"
  cp "$UNIVERSAL_BIN" "$dest/Contents/MacOS/$APP_NAME"
  cp Resources/Info.plist "$dest/Contents/Info.plist"
  # Explicit flat Icon Composer artwork prevents macOS 26 from automatically
  # embossing the legacy ICNS. Keep our hand-rendered ICNS for macOS 13–15.
  echo "==> Compiling flat application icon (Xcode 26+)"
  xcrun actool Resources/MacFanFlat.icon \
    --compile "$dest/Contents/Resources" \
    --app-icon MacFanFlat --platform macosx --target-device mac \
    --minimum-deployment-target 13.0 --development-region en \
    --enable-on-demand-resources NO \
    --enable-icon-stack-fallback-generation=disabled \
    --include-all-app-icons \
    --output-partial-info-plist "$BUILD_DIR/icon-info.plist"
  /usr/libexec/PlistBuddy -c 'Delete :CFBundleIconFile' "$dest/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Merge $BUILD_DIR/icon-info.plist" "$dest/Contents/Info.plist"
  cp Resources/AppIcon.icns "$dest/Contents/Resources/MacFanFlat.icns"
  cp Resources/MenuEyeOn.png Resources/MenuEyeOff.png "$dest/Contents/Resources/"
  cp Resources/PrivacyInfo.xcprivacy "$dest/Contents/Resources/PrivacyInfo.xcprivacy"
  plist_set_string "$dest/Contents/Info.plist" CFBundleName "$APP_NAME"
  plist_set_string "$dest/Contents/Info.plist" CFBundleDisplayName "$APP_NAME"
  plist_set_string "$dest/Contents/Info.plist" CFBundleExecutable "$APP_NAME"
  plist_set_string "$dest/Contents/Info.plist" CFBundleShortVersionString "$MACFAN_VERSION"
  plist_set_string "$dest/Contents/Info.plist" CFBundleVersion "$MACFAN_BUILD"
  plist_set_string "$dest/Contents/Info.plist" CFBundleIdentifier "$BUNDLE_ID"
  echo "==> Version $MACFAN_VERSION ($MACFAN_BUILD)  $BUNDLE_ID"
}

codesign_common_args() {
  CODESIGN_ARGS=(--force --timestamp)
  if [[ -n "${MACFAN_KEYCHAIN:-}" ]]; then
    resolve_existing_file "keychain" "$MACFAN_KEYCHAIN"
    CODESIGN_ARGS+=(--keychain "$RESOLVED_PATH")
  fi
}

sign_adhoc() {
  local dest="$1"
  echo "==> Ad-hoc code signing (required for launch-at-login)"
  codesign --force --deep --sign - "$dest"
}

sign_developer_id() {
  local dest="$1"
  local identity="${DEVELOPER_ID_APPLICATION:-}"
  if [[ -z "$identity" ]]; then
    die "set DEVELOPER_ID_APPLICATION or pass --developer-id (exact name from: security find-identity -v -p codesigning)"
  fi
  echo "==> Developer ID signature with Hardened Runtime"
  codesign_common_args
  codesign "${CODESIGN_ARGS[@]}" --options runtime --sign "$identity" "$dest"
  codesign --verify --strict --verbose=2 "$dest"
}

prepare_mas_entitlements() {
  local team="${APPLE_TEAM_ID:-}"
  local profile_src="${MACFAN_PROVISIONING_PROFILE:-}"
  local profile decoded app_id profile_team sandbox
  if [[ -z "$team" ]]; then
    die "set APPLE_TEAM_ID or pass --team-id (10-character Team ID)"
  fi
  if [[ ! "$team" =~ ^[A-Za-z0-9]{10}$ ]]; then
    die "APPLE_TEAM_ID must be 10 letters or digits (got: $team)"
  fi
  if [[ -z "$profile_src" ]]; then
    die "set MACFAN_PROVISIONING_PROFILE or pass --profile (Mac App Store .provisionprofile)"
  fi
  resolve_existing_file "provisioning profile" "$profile_src"
  profile=$RESOLVED_PATH
  decoded="$BUILD_DIR/profile.plist"
  /usr/bin/security cms -D -i "$profile" > "$decoded"
  app_id=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$decoded" 2>/dev/null || true)
  profile_team=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.team-identifier' "$decoded" 2>/dev/null || true)
  sandbox=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.security.app-sandbox' "$decoded" 2>/dev/null || true)
  if [[ "$sandbox" != "true" ]]; then
    die "provisioning profile is missing com.apple.security.app-sandbox = true"
  fi
  if [[ "$profile_team" != "$team" ]]; then
    die "profile team-identifier ($profile_team) does not match APPLE_TEAM_ID ($team)"
  fi
  if [[ "$app_id" != "$team.$BUNDLE_ID" ]]; then
    die "profile application-identifier ($app_id) does not match $team.$BUNDLE_ID"
  fi
  if grep -q 'iokit-user-client-class' "$decoded"; then
    die "provisioning profile contains an IOKit user-client exception; App Review rejects that. Use App Sandbox only."
  fi
  local expires
  expires=$(/usr/libexec/PlistBuddy -c 'Print :ExpirationDate' "$decoded" 2>/dev/null || true)
  if [[ -n "$expires" ]]; then
    echo "==> Provisioning profile expires: $expires"
  fi
  ENTITLEMENTS="$BUILD_DIR/MacFan-MAS.entitlements"
  cp Resources/MacFan-MAS.entitlements "$ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Set :com.apple.application-identifier $team.$BUNDLE_ID" "$ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Set :com.apple.developer.team-identifier $team" "$ENTITLEMENTS"
  plutil -lint "$ENTITLEMENTS" >/dev/null
  cp "$profile" "$APP_DIR/Contents/embedded.provisionprofile"
}

sign_mas() {
  local identity="${APPLE_DISTRIBUTION_IDENTITY:-}"
  if [[ -z "$identity" ]]; then
    die "set APPLE_DISTRIBUTION_IDENTITY or pass --distribution-identity (exact name from: security find-identity -v -p codesigning)"
  fi
  prepare_mas_entitlements
  echo "==> Apple Distribution signature (App Sandbox, Hardened Runtime)"
  codesign_common_args
  codesign "${CODESIGN_ARGS[@]}" --options runtime --generate-entitlement-der \
    --entitlements "$ENTITLEMENTS" --sign "$identity" "$APP_DIR"
  codesign --verify --strict --verbose=2 "$APP_DIR"
  local signed="$BUILD_DIR/signed-entitlements.plist"
  codesign -d --entitlements :- "$APP_DIR" > "$signed"
  local sandbox
  sandbox=$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$signed" 2>/dev/null || true)
  if [[ "$sandbox" != "true" ]]; then
    die "signed app is missing the app sandbox entitlement"
  fi
}

make_dmg() {
  local staging="$BUILD_DIR/dmg-staging"
  local dmg="$BUILD_DIR/$APP_NAME-v$MACFAN_VERSION.dmg"
  local identity="${DEVELOPER_ID_APPLICATION:-}"
  echo "==> Creating $dmg"
  local volumes volume_status=0
  volumes=$(hdiutil info) || volume_status=$?
  if [[ "$volume_status" -ne 0 ]]; then
    die "hdiutil info failed (exit $volume_status)"
  fi
  # Same pipefail hazard as slice_imports: do not pipe this into grep -q.
  case "$volumes" in
    *"/Volumes/$APP_NAME"*) hdiutil detach "/Volumes/$APP_NAME" || true ;;
  esac
  rm -rf "$staging"
  mkdir -p "$staging"
  cp -R "$APP_DIR" "$staging/$APP_NAME.app"
  ln -s /Applications "$staging/Applications"
  rm -f "$dmg"
  hdiutil create -volname "$APP_NAME" -srcfolder "$staging" -ov -format UDZO "$dmg"
  echo "==> Signing disk image"
  codesign_common_args
  codesign "${CODESIGN_ARGS[@]}" --sign "$identity" "$dmg"
  codesign --verify --verbose=2 "$dmg"
  DMG_PATH=$dmg
}

require_api_credentials() {
  local key_id="$1"
  local issuer="$2"
  if [[ ! "$key_id" =~ ^[A-Za-z0-9]+$ ]]; then
    die "API key id must be alphanumeric (got: $key_id)"
  fi
  if [[ ! "$issuer" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
    die "API issuer must be a UUID (got: $issuer)"
  fi
}

notarize_and_staple() {
  local artifact="$1"
  local -a args
  local key_count=0
  args=(xcrun notarytool submit "$artifact" --wait)
  if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then key_count=$((key_count + 1)); fi
  if [[ -n "${NOTARY_KEY_ID:-}" ]]; then key_count=$((key_count + 1)); fi
  if [[ -n "${NOTARY_ISSUER:-}" ]]; then key_count=$((key_count + 1)); fi
  if [[ "$key_count" -eq 3 ]]; then
    require_api_credentials "$NOTARY_KEY_ID" "$NOTARY_ISSUER"
    resolve_existing_file "notarization API key" "$NOTARY_KEY_PATH"
    args+=(--key "$RESOLVED_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
    echo "==> Notarizing with App Store Connect API key"
  elif [[ "$key_count" -gt 0 ]]; then
    die "set all of NOTARY_KEY_PATH, NOTARY_KEY_ID and NOTARY_ISSUER, or none of them"
  elif [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    args+=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
    if [[ -n "${MACFAN_KEYCHAIN:-}" ]]; then
      resolve_existing_file "keychain" "$MACFAN_KEYCHAIN"
      args+=(--keychain "$RESOLVED_PATH")
    fi
    echo "==> Notarizing with keychain profile $NOTARY_KEYCHAIN_PROFILE"
  else
    die "set NOTARY_KEY_PATH + NOTARY_KEY_ID + NOTARY_ISSUER, or NOTARY_KEYCHAIN_PROFILE"
  fi
  "${args[@]}"
  echo "==> Stapling notarization ticket"
  xcrun stapler staple "$artifact"
  xcrun stapler validate "$artifact"
}

write_product_requirements() {
  local plist="$BUILD_DIR/product-requirements.plist"
  local min_os
  if ! min_os=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_DIR/Contents/Info.plist"); then
    die "could not read LSMinimumSystemVersion"
  fi
  if [[ ! "$min_os" =~ ^[0-9]+([.][0-9]+){0,2}$ ]]; then
    die "unexpected LSMinimumSystemVersion: $min_os"
  fi
  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>os</key>
	<array>
		<string>$min_os</string>
	</array>
	<key>arch</key>
	<array>
		<string>arm64</string>
		<string>x86_64</string>
	</array>
</dict>
</plist>
EOF
  plutil -lint "$plist" >/dev/null
  PRODUCT_REQUIREMENTS=$plist
}

make_pkg() {
  local installer="${MAC_INSTALLER_DISTRIBUTION_IDENTITY:-}"
  local pkg="$BUILD_DIR/$APP_NAME-v$MACFAN_VERSION.pkg"
  if [[ -z "$installer" ]]; then
    die "set MAC_INSTALLER_DISTRIBUTION_IDENTITY or pass --installer-identity (exact name from: security find-identity -v)"
  fi
  write_product_requirements
  echo "==> Building $pkg"
  rm -f "$pkg"
  productbuild \
    --component "$APP_DIR" /Applications \
    --product "$PRODUCT_REQUIREMENTS" \
    --sign "$installer" \
    "$pkg"
  pkgutil --check-signature "$pkg"
  PKG_PATH=$pkg
}

upload_pkg() {
  local key_id="${ASC_KEY_ID:-${NOTARY_KEY_ID:-}}"
  local issuer="${ASC_ISSUER_ID:-${NOTARY_ISSUER:-}}"
  local key_src="${ASC_KEY_PATH:-${NOTARY_KEY_PATH:-}}"
  local apple_id="${ASC_APP_APPLE_ID:-}"
  local pkg_abs
  local -a args
  if [[ -z "$key_id" || -z "$issuer" || -z "$key_src" ]]; then
    die "upload needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (or the NOTARY_KEY_* equivalents)"
  fi
  require_api_credentials "$key_id" "$issuer"
  if [[ -z "$apple_id" ]]; then
    die "upload needs ASC_APP_APPLE_ID (the app's numeric Apple ID in App Store Connect)"
  fi
  if [[ ! "$apple_id" =~ ^[0-9]+$ ]]; then
    die "ASC_APP_APPLE_ID must be numeric (got: $apple_id)"
  fi
  resolve_existing_file "App Store Connect API key" "$key_src"
  pkg_abs="$ROOT/$PKG_PATH"
  MACFAN_KEY_DIR=$(mktemp -d "${TMPDIR:-/tmp}/macfan-keys.XXXXXX") || die "could not create a temporary directory for the API key"
  chmod 700 "$MACFAN_KEY_DIR"
  cp "$RESOLVED_PATH" "$MACFAN_KEY_DIR/AuthKey_${key_id}.p8"
  chmod 600 "$MACFAN_KEY_DIR/AuthKey_${key_id}.p8"
  echo "==> Uploading package (App Store Connect API key $key_id)"
  args=(
    xcrun altool --upload-package "$pkg_abs"
    -t osx
    --apple-id "$apple_id"
    --bundle-id "$BUNDLE_ID"
    --bundle-short-version-string "$MACFAN_VERSION"
    --bundle-version "$MACFAN_BUILD"
    --apiKey "$key_id"
    --apiIssuer "$issuer"
    --show-progress
  )
  if [[ -n "${ASC_PUBLIC_ID:-}" ]]; then
    args+=(--asc-public-id "$ASC_PUBLIC_ID")
  fi
  API_PRIVATE_KEYS_DIR="$MACFAN_KEY_DIR" "${args[@]}"
  rm -rf "$MACFAN_KEY_DIR"
  MACFAN_KEY_DIR=""
}

preflight_notary() {
  local key_count=0
  if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then key_count=$((key_count + 1)); fi
  if [[ -n "${NOTARY_KEY_ID:-}" ]]; then key_count=$((key_count + 1)); fi
  if [[ -n "${NOTARY_ISSUER:-}" ]]; then key_count=$((key_count + 1)); fi
  if [[ "$key_count" -eq 3 ]]; then
    require_api_credentials "$NOTARY_KEY_ID" "$NOTARY_ISSUER"
    resolve_existing_file "notarization API key" "$NOTARY_KEY_PATH"
  elif [[ "$key_count" -gt 0 ]]; then
    die "set all of NOTARY_KEY_PATH, NOTARY_KEY_ID and NOTARY_ISSUER, or none of them"
  elif [[ -z "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    die "set NOTARY_KEY_PATH + NOTARY_KEY_ID + NOTARY_ISSUER, or NOTARY_KEYCHAIN_PROFILE"
  elif [[ -n "${MACFAN_KEYCHAIN:-}" ]]; then
    resolve_existing_file "keychain" "$MACFAN_KEYCHAIN"
  fi
}

preflight_dmg() {
  if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    die "set DEVELOPER_ID_APPLICATION or pass --developer-id (exact name from: security find-identity -v -p codesigning)"
  fi
  preflight_notary
}

preflight_appstore() {
  local team="${APPLE_TEAM_ID:-}"
  if [[ -z "$team" ]]; then
    die "set APPLE_TEAM_ID or pass --team-id (10-character Team ID)"
  fi
  if [[ ! "$team" =~ ^[A-Za-z0-9]{10}$ ]]; then
    die "APPLE_TEAM_ID must be 10 letters or digits (got: $team)"
  fi
  if [[ -z "${APPLE_DISTRIBUTION_IDENTITY:-}" ]]; then
    die "set APPLE_DISTRIBUTION_IDENTITY or pass --distribution-identity (exact name from: security find-identity -v -p codesigning)"
  fi
  if [[ -z "${MAC_INSTALLER_DISTRIBUTION_IDENTITY:-}" ]]; then
    die "set MAC_INSTALLER_DISTRIBUTION_IDENTITY or pass --installer-identity (exact name from: security find-identity -v)"
  fi
  if [[ -z "${MACFAN_PROVISIONING_PROFILE:-}" ]]; then
    die "set MACFAN_PROVISIONING_PROFILE or pass --profile (Mac App Store .provisionprofile)"
  fi
  resolve_existing_file "provisioning profile" "$MACFAN_PROVISIONING_PROFILE"
  if [[ -n "${MACFAN_KEYCHAIN:-}" ]]; then
    resolve_existing_file "keychain" "$MACFAN_KEYCHAIN"
  fi
  if [[ "$MACFAN_UPLOAD" -eq 1 ]]; then
    local key_id="${ASC_KEY_ID:-${NOTARY_KEY_ID:-}}"
    local issuer="${ASC_ISSUER_ID:-${NOTARY_ISSUER:-}}"
    local key_src="${ASC_KEY_PATH:-${NOTARY_KEY_PATH:-}}"
    local apple_id="${ASC_APP_APPLE_ID:-}"
    if [[ -z "$key_id" || -z "$issuer" || -z "$key_src" ]]; then
      die "upload needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (or the NOTARY_KEY_* equivalents)"
    fi
    require_api_credentials "$key_id" "$issuer"
    if [[ -z "$apple_id" ]]; then
      die "upload needs ASC_APP_APPLE_ID (the app's numeric Apple ID in App Store Connect)"
    fi
    if [[ ! "$apple_id" =~ ^[0-9]+$ ]]; then
      die "ASC_APP_APPLE_ID must be numeric (got: $apple_id)"
    fi
    resolve_existing_file "App Store Connect API key" "$key_src"
  fi
}

case "$COMMAND" in
  dmg) preflight_dmg ;;
  appstore) preflight_appstore ;;
esac

require_cmd swift
require_cmd lipo
require_cmd xcrun
require_cmd codesign
require_cmd perl
require_cmd nm
require_cmd plutil
if [[ ! -x /usr/libexec/PlistBuddy ]]; then
  die "required command not found: /usr/libexec/PlistBuddy"
fi

mkdir -p "$BUILD_DIR"

case "$COMMAND" in
  app)
    compile_release direct
    APP_DIR="$BUILD_DIR/$APP_NAME.app"
    assemble_app "$APP_DIR"
    sign_adhoc "$APP_DIR"
    echo "==> Done: $APP_DIR"
    echo "    Install: cp -R $APP_DIR /Applications/"
    ;;
  dmg)
    require_cmd hdiutil
    compile_release direct
    APP_DIR="$BUILD_DIR/$APP_NAME.app"
    assemble_app "$APP_DIR"
    sign_developer_id "$APP_DIR"
    make_dmg
    notarize_and_staple "$DMG_PATH"
    echo "==> Done: $DMG_PATH"
    echo "    GitHub release asset: $(basename "$DMG_PATH") on tag v$MACFAN_VERSION"
    ;;
  appstore)
    require_cmd productbuild
    require_cmd pkgutil
    require_cmd security
    compile_release mas
    APP_DIR="$BUILD_DIR/$APP_NAME-MAS.app"
    assemble_app "$APP_DIR"
    sign_mas
    make_pkg
    if [[ "$MACFAN_UPLOAD" -eq 1 ]]; then
      upload_pkg
    else
      echo "    Upload is off. Re-run with --upload, or set MACFAN_UPLOAD=1, to send the pkg."
    fi
    echo "==> Done: $PKG_PATH"
    echo "    App bundle: $APP_DIR"
    ;;
  *)
    die "unknown command: $COMMAND"
    ;;
esac
