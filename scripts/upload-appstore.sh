#!/usr/bin/env bash
# Validate and upload an already-built App Store package to App Store Connect.
#
# Reads credentials from a `.env` file at the repo root (gitignored). Copy
# `.env.example` to `.env` and fill in AC_USER / AC_PASS first.
#
# This does NOT rebuild — it uploads whatever scripts/make-appstore.sh last
# produced at build/appstore/VTT.pkg, so the version/build you packaged is the
# version/build you ship. Run make-appstore.sh first to (re)create the pkg.
#
# Usage:
#   scripts/upload-appstore.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/build/appstore/VTT.pkg"
ENV_FILE="$ROOT/.env"

[ -f "$ENV_FILE" ] || { echo "✗ No .env at repo root. Copy .env.example to .env and fill it in."; exit 1; }
[ -f "$PKG" ] || { echo "✗ No package at $PKG. Run scripts/make-appstore.sh first."; exit 1; }

# Load .env (export every assignment).
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${AC_USER:?Set AC_USER in .env (Apple ID email)}"
: "${AC_PASS:?Set AC_PASS in .env (app-specific password)}"

echo "› Package: $PKG"
echo "  Version: $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' -c 'Print CFBundleVersion' \
  "$ROOT/build/appstore/VTT.app/Contents/Info.plist" 2>/dev/null | paste -sd' ' -)"

echo "› Validating with App Store Connect…"
xcrun altool --validate-app -f "$PKG" -t macos -u "$AC_USER" -p "$AC_PASS"

echo "› Uploading…"
xcrun altool --upload-app -f "$PKG" -t macos -u "$AC_USER" -p "$AC_PASS"

echo "✓ Uploaded. Check App Store Connect → your app → TestFlight/Builds (processing takes a few minutes)."
