#!/usr/bin/env bash
# DEVELOPER tool — reset VTT's free-tier daily usage counter during testing.
#
# Note: end users can't do this trivially. Usage now lives in a signed blob in
# the Keychain + a hidden Application Support file (see UsageVault.swift), not in
# plain UserDefaults, so there's no one-line `defaults delete` bypass. This script
# clears every store because the developer knows where they all are.
set -euo pipefail

osascript -e 'tell application "VTT" to quit' 2>/dev/null || true
killall VTT 2>/dev/null && echo "› VTT quit" || echo "› VTT not running"
sleep 1

# 1) Keychain copy (service/account match UsageVault).
if security delete-generic-password -s "com.mgorunuch.vtt.s" -a "d" >/dev/null 2>&1; then
  echo "  reset: keychain blob"
else
  echo "  absent: keychain blob"
fi

# 2) Signed file copy (non-sandbox and sandbox paths).
for f \
  in "$HOME/Library/Application Support/.vtt-dcache" \
     "$HOME/Library/Containers/com.mgorunuch.vtt/Data/Library/Application Support/.vtt-dcache"; do
  if [ -f "$f" ]; then rm -f "$f" && echo "  reset: $f"; fi
done

# 3) Legacy UserDefaults keys (pre-hardening builds).
for k in dailyUsageSeconds dailyUsageDay dailyBegs; do
  defaults delete com.mgorunuch.vtt "$k" >/dev/null 2>&1 && echo "  reset (legacy): $k" || true
done

echo "✓ Usage reset — daily quota is full again."
