#!/bin/bash
# Finds features that are complete but unreachable.
#
# This project inherits a specific failure mode from Anchor, which shipped it
# repeatedly: code that is written, correct and tested, but that no user can
# ever reach. It never fails a build and never throws — there is simply nothing
# to find. VinylPod's own adversarial review turned up six instances in one
# pass, including two notifications that were observed and never posted.
#
# Four checks, each for a shape that has actually occurred here:
#
#   1. A Defaults key that nothing outside Settings reads      (a dead switch)
#   2. A Defaults key that no UI exposes                        (unreachable)
#   3. A Notification.Name posted with no observer, or observed
#      with no poster                                           (silent no-op)
#   4. A PlayerElement case with no renderer                    (draws nothing)
#
# Exits non-zero if anything is found, so CI can run it.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
note() { printf '  %s\n' "$1"; }

# --- 1 & 2: Defaults keys ---------------------------------------------------
echo "Defaults keys"
keys=$(grep -oE 'static let [a-zA-Z0-9]+ = Key<' Sources/Support/MusicDefaults.swift \
       | awk '{print $3}')
for key in $keys; do
    # Every reference outside the key declaration itself.
    refs=$(grep -rl "\.$key\b" Sources --include='*.swift' | grep -v 'MusicDefaults.swift' || true)
    ui=$(echo "$refs" | grep -c 'Sources/Settings/' || true)
    code=$(echo "$refs" | grep -vc 'Sources/Settings/' || true)

    if [ -z "$refs" ]; then
        note "UNREAD + UNREACHABLE: $key — nothing references it at all"
        fail=1
    elif [ "$code" -eq 0 ]; then
        note "DEAD SWITCH: $key — only Settings reads it, so it drives nothing"
        fail=1
    elif [ "$ui" -eq 0 ]; then
        # Not automatically wrong: some keys are internal state rather than
        # preferences. The allowlist below is the record of which, and why.
        case "$key" in
            # Written by the editor or by dragging, not by a control.
            playerLayouts|playerWidth|playerHeightBudget)
                ;;
            # The launcher card is not reachable until Anchor integration, so
            # its two keys legitimately have no UI yet. Revisit at integration.
            launcherWidgetSize|launcherAlwaysShowsControls)
                ;;
            # Managed by SpotifyAuthManager. Tokens are not preferences, and a
            # control that let you type one would be a mistake.
            spotifyAuthAccessToken|spotifyAuthAccessTokenExpiration|spotifyAuthLastValidatedAt)
                ;;
            # One-shot migration bookkeeping.
            didClearLegacyURLCacheV1)
                ;;
            # Internal timing: how long playback must be idle before the player
            # says so. Exposing it would be a knob nobody wants to reason about.
            waitInterval)
                ;;
            # Vestigial from the extraction. Read by AnchorAnimations, which
            # MusicManager still holds, but VinylPod has no notch to animate.
            # Left rather than deleted so the file folds back into Anchor.
            notchAnimationProfile)
                ;;
            # Notch-era behaviours that survive as data paths but have no
            # surface here: the sneak peek now only posts a notification, and
            # the horizontal skip gesture belongs to a notch that does not
            # exist. Delete these when it is clear nothing wants them back.
            enableSneakPeek|showSneakPeekOnTrackChange|enableHorizontalMusicGestures|musicGestureBehavior)
                ;;
            *)
                note "NO UI: $key — read by code, but nothing lets the user set it"
                fail=1 ;;
        esac
    fi
done

# --- 3: notifications -------------------------------------------------------
echo "Notification names"
names=$(grep -rhoE 'static let [a-zA-Z0-9]+ = Notification\.Name' Sources --include='*.swift' \
        | awk '{print $3}')
for name in $names; do
    posted=$(grep -rl "post(name: \.$name" Sources --include='*.swift' | wc -l | tr -d ' ')
    observed=$(grep -rlE "(publisher\(for: (Notification\.Name\.)?\.?$name)|(addObserver.*[: ]\.$name)|(name: \.$name,)" \
               Sources --include='*.swift' | grep -v 'post(name' | wc -l | tr -d ' ')
    if [ "$posted" -eq 0 ] && [ "$observed" -gt 0 ]; then
        note "OBSERVED, NEVER POSTED: .$name — the observer can never fire"
        fail=1
    fi
    if [ "$posted" -gt 0 ] && [ "$observed" -eq 0 ]; then
        note "POSTED, NEVER OBSERVED: .$name — the post goes nowhere"
        fail=1
    fi
done

# --- 4: elements ------------------------------------------------------------
echo "PlayerElement cases"
cases=$(grep -oE '^    case [a-zA-Z]+' Sources/Layout/PlayerElement.swift \
        | awk '{print $2}' | tr -d ',')
for element in $cases; do
    if ! grep -q "case \.$element" Sources/Layout/PlayerSurfaceView.swift; then
        note "NO RENDERER: .$element is placeable but PlayerSurfaceView never draws it"
        fail=1
    fi
done

echo
if [ "$fail" -eq 0 ]; then
    echo "OK — nothing unreachable"
else
    echo "Found unreachable code. Each line above is a feature no user can get to."
fi
exit $fail
