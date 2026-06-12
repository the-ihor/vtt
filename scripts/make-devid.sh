#!/usr/bin/env bash
# Build, sign, notarize, and package VTT for direct distribution (outside the
# App Store): Developer ID signature + hardened runtime + notarized dmg.
#
# Prerequisites:
#   1. A "Developer ID Application" certificate in the login keychain
#      (Xcode → Settings → Accounts → Manage Certificates — Account Holder only)
#   2. The App Store Connect app-specific password saved in the keychain as
#      "VTT-ASC" (security add-generic-password -s VTT-ASC …) — notarytool
#      uses the same credential.
#
# Usage:  scripts/make-devid.sh
# Env:    SIGN_ID  – override the signing identity
#         TEAM_ID  – defaults to 752556J5V6
#         AC_USER  – defaults to mgorunuch.igor@gmail.com
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/devid"
APP="$OUT/VTT.app"
DMG="$OUT/VTT.dmg"
TEAM_ID="${TEAM_ID:-752556J5V6}"
AC_USER="${AC_USER:-mgorunuch.igor@gmail.com}"

SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning | grep -m1 "Developer ID Application.*($TEAM_ID)" | sed -E 's/.*"(.*)"/\1/')}"
[ -n "$SIGN_ID" ] || { echo "✗ No 'Developer ID Application' certificate for team $TEAM_ID in the keychain"; exit 1; }

echo "› Building universal release (DIRECT_DISTRIBUTION)…"
swift build -c release --package-path "$ROOT" --arch arm64 --arch x86_64 \
  -Xswiftc -DDIRECT_DISTRIBUTION
BIN="$(swift build -c release --package-path "$ROOT" --arch arm64 --arch x86_64 \
  -Xswiftc -DDIRECT_DISTRIBUTION --show-bin-path)/VTT"

echo "› Assembling bundle…"
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/VTT"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
if ls "$ROOT"/Resources/Logos/*.png >/dev/null 2>&1; then
  cp "$ROOT"/Resources/Logos/*.png "$APP/Contents/Resources/"
fi
xcrun actool --compile "$APP/Contents/Resources" \
  "$ROOT/Resources/Assets.xcassets" \
  --platform macosx --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist /tmp/vtt-actool-devid.plist >/dev/null
xattr -cr "$APP"

# Hardened runtime is required for notarization. The mic entitlement is the
# only resource-access exception the app needs; no sandbox outside the store.
echo "› Signing with '$SIGN_ID'…"
codesign --force --sign "$SIGN_ID" \
  --entitlements "$ROOT/Resources/VTT.entitlements" \
  --options runtime --timestamp "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "› Creating dmg…"
STAGE="$OUT/stage"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "VTT" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --force --sign "$SIGN_ID" --timestamp "$DMG"

echo "› Notarizing (waits for Apple)…"
AC_PASS="$(security find-generic-password -s VTT-ASC -w)"
xcrun notarytool submit "$DMG" \
  --apple-id "$AC_USER" --team-id "$TEAM_ID" --password "$AC_PASS" \
  --wait

echo "› Stapling…"
xcrun stapler staple "$DMG"

echo "✓ Notarized dmg ready: $DMG"
echo "  Verify with: spctl -a -t open --context context:primary-signature -v \"$DMG\""
