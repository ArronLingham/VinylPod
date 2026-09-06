#!/bin/bash
# Writes hostile values into every setting and checks the app survives.
#
# LIVE — this launches the real app and edits the real preferences domain. It is
# not part of the unit run. It backs the domain up first and restores it at the
# end, including on failure.
#
# Worth having because the unit harness tests `GridSolver` against layouts a
# programmer wrote. This tests it against layouts nobody wrote: a span of 900, a
# negative row, a column past the grid, a duplicated element, JSON that is not a
# layout at all. Those arrive from a hand-edited plist, from a settings file
# synced off a machine running a newer version, or from a bug.
#
# Anchor found a real SIGTRAP this way — `UInt64(aDouble)` in its network-rate
# code — that no amount of reading had caught.
#
# PROVED NON-VACUOUS. Adding `precondition(geometry.columns > 0)` to
# GridSolver.solve — removing the `max(1, columns)` clamp that makes a
# zero-column layout survivable — turns this red:
#
#     CRASH layout: {"desktop":{"geometry":{"columns":0,...
#     CRASH layout: {"desktop":{"geometry":{"columns":-5,...
#     crash reports written during this run: 1
#     3 failure(s)
#
# A stress test that cannot detect a crash is decoration. Re-run that control
# after changing what this harness writes.
set -uo pipefail
cd "$(dirname "$0")/.."

DOMAIN=com.arronlingham.VinylPod
APP=$(find ~/Library/Developer/Xcode/DerivedData/VinylPod-*/Build/Products/Debug \
      -maxdepth 1 -name 'VinylPod.app' 2>/dev/null | head -1)
[ -n "$APP" ] || { echo "no Debug build — build it first"; exit 1; }

BACKUP=$(mktemp -t vinylpod-prefs).plist
CRASHES=~/Library/Logs/DiagnosticReports

restore() {
    echo
    echo "restoring your settings"
    pkill -x VinylPod 2>/dev/null
    defaults delete "$DOMAIN" 2>/dev/null
    if [ -s "$BACKUP" ]; then defaults import "$DOMAIN" "$BACKUP" 2>/dev/null; fi
    rm -f "$BACKUP"
}
trap restore EXIT

defaults export "$DOMAIN" "$BACKUP" 2>/dev/null || true
crashes_before=$(ls "$CRASHES" 2>/dev/null | grep -c VinylPod || true)

launch() {
    pkill -x VinylPod 2>/dev/null
    while pgrep -x VinylPod >/dev/null; do sleep 0.2; done
    open -n "$APP"
    for _ in $(seq 1 40); do pgrep -x VinylPod >/dev/null && break; sleep 0.25; done
}

alive() { pgrep -x VinylPod >/dev/null; }

failures=0
check() {  # name
    sleep 3
    if alive; then
        printf '  ok    %s\n' "$1"
    else
        printf '  CRASH %s\n' "$1"
        failures=$((failures + 1))
    fi
}

# ---------------------------------------------------------------------------
echo "Extreme numbers"
# Every numeric key, at values no UI can produce.
for value in -99999999 -1 0 99999999; do
    for key in playerWidth playerHeightBudget playerBackgroundOpacity \
               lockWidgetWidth lockWidgetVerticalOffset lyricsOffsetSeconds \
               visualizerBarCount lyricsVisibleLines waitInterval; do
        defaults write "$DOMAIN" "$key" -float "$value" 2>/dev/null
    done
    launch
    check "every numeric key at $value"
done

# ---------------------------------------------------------------------------
echo "Hostile strings in typed keys"
# Type confusion: a String where an enum, a Double or a Bool is expected.
for value in "" " " "🎵🎵🎵" "../../etc/passwd" "'; DROP TABLE --" \
             "$(printf 'x%.0s' {1..500})"; do
    for key in playerWindowLevel mediaController lockFullBackground \
               playerWidth enablePlayerWidget spotifySPDCCookie; do
        defaults write "$DOMAIN" "$key" -string "$value" 2>/dev/null
    done
    launch
    check "typed keys holding a string of length ${#value}"
done

# ---------------------------------------------------------------------------
echo "Malformed layouts"
# The engine's own input. Each of these is a layout no editor can produce.
layouts=(
  'not json at all'
  '{}'
  '{"desktop":null}'
  '{"desktop":{"geometry":{"columns":0,"padding":0,"gutter":0},"placements":[]}}'
  '{"desktop":{"geometry":{"columns":-5,"padding":-100,"gutter":-100},"placements":[]}}'
  '{"desktop":{"geometry":{"columns":99999,"padding":0,"gutter":0},"placements":[]}}'
  '{"desktop":{"geometry":{"columns":6},"placements":[{"element":"artwork","col":900,"row":900,"colSpan":900}]}}'
  '{"desktop":{"geometry":{"columns":6},"placements":[{"element":"artwork","col":-9,"row":-9,"colSpan":-9}]}}'
  '{"desktop":{"geometry":{"columns":6},"placements":[{"element":"notAnElement","col":0,"row":0}]}}'
  '{"desktop":{"geometry":{"columns":6},"placements":[{"element":"playPause","col":0,"row":0,"layer":"nonsense","visibility":"nonsense"}]}}'
)
# The same element fifty times in one cell.
dupes='{"desktop":{"geometry":{"columns":6},"placements":['
for i in $(seq 1 50); do
    dupes+='{"element":"playPause","col":0,"row":0,"colSpan":1},'
done
layouts+=("${dupes%,}]}}")

for layout in "${layouts[@]}"; do
    defaults delete "$DOMAIN" 2>/dev/null
    defaults write "$DOMAIN" playerLayouts -string "$layout"
    launch
    check "layout: $(echo "$layout" | cut -c1-58)"
done

# ---------------------------------------------------------------------------
echo "Toggle storm"
# Flip every boolean repeatedly while the app is running, to shake out anything
# that assumes a setting changes at most once.
defaults delete "$DOMAIN" 2>/dev/null
launch
for _ in $(seq 1 40); do
    for key in enablePlayerWidget playerTintsWithAlbum hoverGrowsWidget \
               enableLockScreenWidget enableLyrics coloredSpectrogram; do
        defaults write "$DOMAIN" "$key" -bool true
        defaults write "$DOMAIN" "$key" -bool false
    done
done
check "240 boolean flips against a running app"

# ---------------------------------------------------------------------------
echo
crashes_after=$(ls "$CRASHES" 2>/dev/null | grep -c VinylPod || true)
new_crashes=$((crashes_after - crashes_before))
echo "crash reports written during this run: $new_crashes"
if [ "$new_crashes" -gt 0 ]; then
    ls -t "$CRASHES" | grep VinylPod | head -3 | sed 's/^/  /'
    failures=$((failures + new_crashes))
fi

if [ "$failures" -eq 0 ]; then
    echo "OK — survived everything"
else
    echo "$failures failure(s)"
fi
exit $((failures > 0 ? 1 : 0))
