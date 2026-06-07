#!/usr/bin/env bash
# Generate every icon/favicon from the single master: docs/assets/logo.svg
# Requires: rsvg-convert, ImageMagick (magick), iconutil (macOS).
# Run from the repo root or anywhere — paths are resolved relative to this script.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # docs/assets
DOCS="$(cd "$HERE/.." && pwd)"                          # docs
SRC="$HERE/logo.svg"
OUT="$HERE/icons"
mkdir -p "$OUT"

echo "Rendering PNGs from $SRC ..."
for s in 16 32 48 64 128 180 192 256 512 1024; do
  rsvg-convert -w "$s" -h "$s" "$SRC" -o "$OUT/icon-$s.png"
done

# App Store / marketing icon (1024, no alpha — flatten onto the icon's own bg)
magick "$OUT/icon-1024.png" -background "#131210" -alpha remove -alpha off "$OUT/appstore-1024.png"

# Web essentials at the site root
magick "$OUT/icon-16.png" "$OUT/icon-32.png" "$OUT/icon-48.png" "$DOCS/favicon.ico"
cp "$OUT/icon-180.png" "$DOCS/apple-touch-icon.png"

# macOS .icns (for the app bundle)
ICONSET="$(mktemp -d)/VTT.iconset"; mkdir -p "$ICONSET"
rsvg-convert -w 16   -h 16   "$SRC" -o "$ICONSET/icon_16x16.png"
rsvg-convert -w 32   -h 32   "$SRC" -o "$ICONSET/icon_16x16@2x.png"
rsvg-convert -w 32   -h 32   "$SRC" -o "$ICONSET/icon_32x32.png"
rsvg-convert -w 64   -h 64   "$SRC" -o "$ICONSET/icon_32x32@2x.png"
rsvg-convert -w 128  -h 128  "$SRC" -o "$ICONSET/icon_128x128.png"
rsvg-convert -w 256  -h 256  "$SRC" -o "$ICONSET/icon_128x128@2x.png"
rsvg-convert -w 256  -h 256  "$SRC" -o "$ICONSET/icon_256x256.png"
rsvg-convert -w 512  -h 512  "$SRC" -o "$ICONSET/icon_256x256@2x.png"
rsvg-convert -w 512  -h 512  "$SRC" -o "$ICONSET/icon_512x512.png"
rsvg-convert -w 1024 -h 1024 "$SRC" -o "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$OUT/VTT.icns"

echo "Done. Outputs in $OUT plus $DOCS/favicon.ico and $DOCS/apple-touch-icon.png"
ls -1 "$OUT"
