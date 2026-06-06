#!/usr/bin/env bash
# Build VTT and wrap the binary in a proper .app bundle so it can request
# microphone/accessibility permissions and launch like a normal macOS app.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/VTT.app"

echo "› Building ($CONFIG)…"
swift build -c "$CONFIG" --package-path "$ROOT"
BIN="$(swift build -c "$CONFIG" --package-path "$ROOT" --show-bin-path)/VTT"

echo "› Assembling bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/VTT"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Bundle provider brand logos if present (optional). Drop official PNGs into
# Resources/Logos/ (openai.png, deepgram.png, elevenlabs.png) to use real logos.
if ls "$ROOT"/Resources/Logos/*.png >/dev/null 2>&1; then
  cp "$ROOT"/Resources/Logos/*.png "$APP/Contents/Resources/"
fi

# Sign with a stable identity so macOS keeps the same TCC identity across
# rebuilds — otherwise an ad-hoc signature's hash changes every build and the
# Accessibility/Microphone grants silently reset. Override with CODESIGN_ID;
# falls back to the first local Apple Development cert, then ad-hoc.
SIGN_ID="${CODESIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -m1 "Apple Development" | sed -E 's/.*\) ([0-9A-F]+) ".*/\1/')}"

if [ -n "${SIGN_ID:-}" ]; then
  echo "› Signing with ${SIGN_ID}…"
  codesign --force --deep --sign "$SIGN_ID" "$APP"
else
  echo "› Ad-hoc signing (no stable identity found; Accessibility grant will reset each build)…"
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "✓ Built $APP"
echo "  Run with: open \"$APP\"   (or: \"$APP/Contents/MacOS/VTT\")"
