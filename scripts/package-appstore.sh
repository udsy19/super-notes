#!/bin/bash
# Signs and packages the Mac App Store edition.
#
#   ADHOC=1 ./scripts/package-appstore.sh [--debug]
#       Ad-hoc signed, sandboxed build/appstore/Super Notes.app for local testing (no .pkg). The sandbox is enforced.
#
#   APPSTORE_APP_IDENTITY="Apple Distribution: … (TEAMID)" \
#   APPSTORE_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: … (TEAMID)" \
#   APPSTORE_PROVISIONING_PROFILE=/path/to/SuperNotes_AppStore.provisionprofile \
#   ./scripts/package-appstore.sh
#       Store-signed app + dist/SuperNotes-<version>-AppStore.pkg ready for Transporter / notarytool-free upload.
#
# Nested code is signed inside-out (llama.framework, then the app) with the Store entitlements; no
# disable-library-validation: the framework and the app carry the same Team ID, so library validation passes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
DEBUG_FLAG=(); [ "${1:-}" = "--debug" ] && DEBUG_FLAG=(--debug)
ENT="$ROOT/Resources/SuperNotes-AppStore.entitlements"

if [ "${ADHOC:-0}" != 1 ]; then
  missing=()
  [ -n "${APPSTORE_APP_IDENTITY:-}" ] || missing+=("APPSTORE_APP_IDENTITY (\"Apple Distribution: <Name> (<TEAMID>)\")")
  [ -n "${APPSTORE_INSTALLER_IDENTITY:-}" ] || missing+=("APPSTORE_INSTALLER_IDENTITY (\"3rd Party Mac Developer Installer: <Name> (<TEAMID>)\")")
  [ -f "${APPSTORE_PROVISIONING_PROFILE:-/nonexistent}" ] || missing+=("APPSTORE_PROVISIONING_PROFILE (path to the Mac App Store .provisionprofile for the Store bundle ID)")
  if [ ${#missing[@]} -gt 0 ]; then
    echo "error: cannot sign for the Mac App Store; missing:" >&2
    for m in "${missing[@]}"; do echo "  - $m" >&2; done
    echo "For a local sandboxed test build run: ADHOC=1 $0" >&2
    exit 2
  fi
fi

DISTRIBUTION=appstore "$ROOT/scripts/build-app.sh" ${DEBUG_FLAG[@]+"${DEBUG_FLAG[@]}"}
APP="$ROOT/build/appstore/Super Notes.app"
FW="$APP/Contents/Frameworks/llama.framework"

# Uploads with quarantined files are rejected; downloaded artifacts (the llama.cpp zip) can carry the flag.
xattr -cr "$APP"

if [ "${ADHOC:-0}" = 1 ]; then
  codesign -f -s - "$FW"
  codesign -f -s - --entitlements "$ENT" "$APP"
else
  cp "$APPSTORE_PROVISIONING_PROFILE" "$APP/Contents/embedded.provisionprofile"
  # The profile supplies the application identifier and team; merge them into the signed entitlements.
  SIGN_ENT="$(mktemp -t supernotes-ent).plist"
  trap 'rm -f "$SIGN_ENT"' EXIT
  cp "$ENT" "$SIGN_ENT"
  PROFILE_PLIST="$(mktemp -t supernotes-profile).plist"
  security cms -D -i "$APPSTORE_PROVISIONING_PROFILE" > "$PROFILE_PLIST"
  APP_ID=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.application-identifier" "$PROFILE_PLIST")
  TEAM=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.developer.team-identifier" "$PROFILE_PLIST")
  rm -f "$PROFILE_PLIST"
  /usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $APP_ID" "$SIGN_ENT"
  /usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $TEAM" "$SIGN_ENT"
  codesign -f -s "$APPSTORE_APP_IDENTITY" --timestamp "$FW"
  codesign -f -s "$APPSTORE_APP_IDENTITY" --timestamp --entitlements "$SIGN_ENT" "$APP"
fi
codesign --verify --deep --strict "$APP"
if codesign -d --entitlements :- "$APP" 2>/dev/null | grep -qE "disable-library-validation|apple-events|allow-unsigned|temporary-exception"; then
  echo "error: the App Store build carries a forbidden entitlement" >&2; exit 1
fi
codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "com.apple.security.app-sandbox" || { echo "error: not sandboxed" >&2; exit 1; }

if [ "${ADHOC:-0}" = 1 ]; then echo "Ad-hoc sandboxed build: $APP"; exit 0; fi
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
mkdir -p "$ROOT/dist"
PKG="$ROOT/dist/SuperNotes-$VERSION-AppStore.pkg"
productbuild --component "$APP" /Applications --sign "$APPSTORE_INSTALLER_IDENTITY" "$PKG"
echo "Built $PKG (upload with Transporter, or: xcrun altool --upload-app -t macos -f \"$PKG\" … once Xcode is installed)"
