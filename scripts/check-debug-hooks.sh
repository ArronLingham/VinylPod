#!/bin/bash
# Assert that no VINYLPOD_* environment hook survives into a Release build.
#
# The lock-screen preview hook puts a window at CGShieldingWindowLevel over
# everything because an environment variable said so. That is a development aid
# and nothing more; a shipped build must not honour it. Anchor shipped exactly
# this shape of hook unguarded once, and because it rendered the settings pane
# that displays a Keychain value, anyone running as the user could read the
# credential out of a PNG.
#
# THE DEBUG ARM IS THE POINT. Checking only Release passes trivially if the
# grep can no longer find the string anywhere -- a guard that cannot fail. The
# string lives in VinylPod.debug.dylib, not the main binary, so a naive check
# of Contents/MacOS/VinylPod reports 0 for BOTH configurations and proves
# nothing. This script fails if the Debug build does not contain it.
set -euo pipefail
cd "$(dirname "$0")/.."

find_bundle() {
    find ~/Library/Developer/Xcode/DerivedData/VinylPod-*/Build/Products/"$1" \
        -maxdepth 1 -name 'VinylPod.app' 2>/dev/null | head -1
}

count_in() {  # every mach-o in the bundle, not just the main binary
    local bundle="$1" total=0
    for f in "$bundle"/Contents/MacOS/*; do
        [ -f "$f" ] || continue
        total=$(( total + $(strings -a "$f" 2>/dev/null | grep -c 'VINYLPOD_' || true) ))
    done
    echo "$total"
}

debug=$(find_bundle Debug)
release=$(find_bundle Release)
[ -n "$debug" ]   || { echo "no Debug build found — build it first";   exit 1; }
[ -n "$release" ] || { echo "no Release build found — build it first"; exit 1; }

d=$(count_in "$debug")
r=$(count_in "$release")
echo "Debug:   $d occurrence(s) of VINYLPOD_"
echo "Release: $r occurrence(s) of VINYLPOD_"

fail=0
[ "$d" -gt 0 ] || { echo "FAIL: the Debug build has no hook — this check is vacuous"; fail=1; }
[ "$r" -eq 0 ] || { echo "FAIL: a VINYLPOD_ hook survived into Release"; fail=1; }
[ "$fail" -eq 0 ] && echo "OK: hooks present in Debug, absent from Release"
exit $fail
