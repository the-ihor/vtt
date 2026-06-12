#!/usr/bin/env bash
# Build, sign, and package VTT for Mac App Store submission.
#
# Prerequisites (one-time, in the developer portal / App Store Connect):
#   1. App ID "com.the-ihor.vtt" registered at developer.apple.com
#   2. "Apple Distribution" and "Mac Installer Distribution" certificates
#      installed in the login keychain
#   3. A "Mac App Store" provisioning profile for the App ID, downloaded locally
#   4. The app record created in App Store Connect
#
# Usage:
#   TEAM_ID=XXXXXXXXXX PROFILE=~/Downloads/VTT_AppStore.provisionprofile \
#     scripts/make-appstore.sh
#
# Optional env:
#   SIGN_APP  – app signing identity   (default: first "Apple Distribution" cert)
#   SIGN_PKG  – installer identity     (default: first "3rd Party Mac Developer Installer" cert)
#   AC_USER / AC_PASS – Apple ID + app-specific password; if set, the pkg is
#                       validated and uploaded with altool. Otherwise drag the
#                       pkg into Transporter.app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/VTT.app"
PKG="$ROOT/build/VTT.pkg"

: "${TEAM_ID:?Set TEAM_ID to your Apple Developer Team ID (e.g. TEAM_ID=AB12CD34EF)}"
: "${PROFILE:?Set PROFILE to the path of the Mac App Store .provisionprofile}"
[ -f "$PROFILE" ] || { echo "✗ Provisioning profile not found: $PROFILE"; exit 1; }

# Match certs by TEAM_ID so stale identities from other teams in the keychain
# are never picked up.
SIGN_APP="${SIGN_APP:-$(security find-identity -v -p codesigning | grep -m1 "Apple Distribution.*($TEAM_ID)" | sed -E 's/.*"(.*)"/\1/')}"
SIGN_PKG="${SIGN_PKG:-$(security find-identity -v | grep -m1 "3rd Party Mac Developer Installer.*($TEAM_ID)" | sed -E 's/.*"(.*)"/\1/')}"
[ -n "$SIGN_APP" ] || { echo "✗ No 'Apple Distribution' certificate in the keychain"; exit 1; }
[ -n "$SIGN_PKG" ] || { echo "✗ No 'Mac Installer Distribution' certificate in the keychain"; exit 1; }

echo "› Building universal release…"
swift build -c release --package-path "$ROOT" --arch arm64 --arch x86_64
BIN="$(swift build -c release --package-path "$ROOT" --arch arm64 --arch x86_64 --show-bin-path)/VTT"

echo "› Assembling bundle…"
rm -rf "$APP" "$PKG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/VTT"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
if ls "$ROOT"/Resources/Logos/*.png >/dev/null 2>&1; then
  cp "$ROOT"/Resources/Logos/*.png "$APP/Contents/Resources/"
fi
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"

# The App Store requires the icon as a compiled asset catalog (ITMS-90546);
# the .icns alone isn't enough. actool emits Assets.car next to the icns.
echo "› Compiling asset catalog…"
xcrun actool --compile "$APP/Contents/Resources" \
  "$ROOT/Resources/Assets.xcassets" \
  --platform macosx --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist /tmp/vtt-actool.plist >/dev/null

# Files that traveled through a browser (the provisioning profile) carry
# com.apple.quarantine, which App Store delivery rejects (ITMS-91109).
xattr -cr "$APP"

echo "› Signing with '$SIGN_APP'…"
ENT="$ROOT/build/VTT-AppStore.entitlements"
sed "s/@TEAM_ID@/$TEAM_ID/g" "$ROOT/Resources/VTT-AppStore.entitlements" > "$ENT"
codesign --force --sign "$SIGN_APP" --entitlements "$ENT" --timestamp "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "› Building installer package…"
productbuild --component "$APP" /Applications --sign "$SIGN_PKG" "$PKG"

if [ -n "${AC_USER:-}" ] && [ -n "${AC_PASS:-}" ]; then
  echo "› Validating with App Store Connect…"
  xcrun altool --validate-app -f "$PKG" -t macos -u "$AC_USER" -p "$AC_PASS"
  echo "› Uploading…"
  xcrun altool --upload-app -f "$PKG" -t macos -u "$AC_USER" -p "$AC_PASS"
  echo "✓ Uploaded $PKG — check App Store Connect → TestFlight/Builds"
else
  echo "✓ Built $PKG"
  echo "  Upload it with Transporter.app (drag the pkg in), or re-run with AC_USER/AC_PASS set."
fi
