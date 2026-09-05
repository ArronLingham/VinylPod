# Testing VinylPod

Organised by **what you need in order to run it**, not by when it was written.
New checks go in the section they belong to. Do not append a dated section —
that is how Anchor's checklist grew to 770 lines of archaeology.

## Already proven, do not re-test by hand

`tests/run_gridsolver_tests.sh` — **70 assertions**, compiling the real
`Sources/Layout/*.swift`. Covers the four shipped defaults as data (no
overlapping bases, contiguous rows, nothing overflowing the grid, every span
meets `minSpan`, a priority-0 element exists, no orphaned overlays), overlap
resolution, height derivation, priority dropping and its termination,
monotonicity under height, orphaned-overlay removal, compaction keeping an
overlay with its base, hover growth being derived from fit, malformed input
being clamped rather than fatal, the editor predicates, and Codable
forward-compatibility.

Every guard was proved non-vacuous by breaking it — the results are recorded at
the bottom of that file, including the one control that initially passed.

Driven live against the running app during Phase 3, and also not worth
repeating by hand unless something changes:

| Behaviour | Result |
|---|---|
| Widget reaches the window server | 320x465, opaque, onscreen |
| Hover growth | 348 → 372 → 348, top edge fixed |
| No flutter at the bottom edge | 12 samples over 2.2 s, all 372 |
| Width resize | 320 → 480, height followed to 532 |
| Width clamp | stops at exactly 140 |
| Height budget drag | 372 → 80, clamped, persisted |
| Priority dropping | at budget 330 the title is gone, artwork remains |
| Double-click dead space | window level 0 → -2147483602 |
| Card opacity | 0.30/0.92/1.00 → measurably blended, monotone |

## Lock screen

Both surfaces are the same `PlayerSurfaceView` as the desktop player, against
their own layouts. Preview them **without locking the machine**:

```bash
open -n <build>/VinylPod.app --env VINYLPOD_PREVIEW_LOCK=widget
open -n <build>/VinylPod.app --env VINYLPOD_PREVIEW_LOCK=full
```

Debug only. `scripts/check-debug-hooks.sh` asserts it is compiled out of
Release **and** that it is present in Debug — the second half is what stops the
check being vacuous, since the string lives in `VinylPod.debug.dylib` and a
naive grep of `Contents/MacOS/VinylPod` reports 0 for both configurations.

Verified by preview: the widget draws at 380x175, the full-screen player at
1470x956, both at `CGShieldingWindowLevel` (2147483628), both opaque.

**What the preview cannot tell you, and what therefore remains unverified:**

- **Whether the panel actually appears above the lock screen.** That is the
  SkyLight delegation, and `CGShieldingWindowLevel` alone is not enough — it
  clears ordinary windows but not loginwindow's shield. The only way to know is
  to lock the screen and look.
- Whether lock and unlock detection fire. The distributed notifications
  (`com.apple.screenIsLocked` / `…Unlocked`) only arrive from a real lock.
- Whether the 500 ms unlock poll stops. It runs only while locked and cancels
  on unlock, but that path has never executed.

Lock the screen once, by hand, and check: the widget appears, double-clicking
the artwork expands it to full screen, and both are gone after unlocking.

## What only a person can check

In rough order of how bad it would be to get wrong.

1. **Playback, end to end.** Every automated check above ran with nothing
   playing, so the player showed its placeholder (`I'm Handsome` / `Me` /
   `Self Love` — those strings are `MusicManager`'s defaults, not a bug). Play
   something in Music, Spotify, YouTube Music and Amazon Music in turn and
   confirm the title, artist, album, artwork and progress are right and that
   transport works. **Nothing in this repo has yet seen a real track.**
2. **Does the record look right turning?** It is a `CABasicAnimation` handed to
   the render server once. Check it starts on play, holds position on pause
   rather than snapping to zero, and does not visibly swell when the window
   moves between displays.
3. **Does the resize feel right?** Grab each edge and corner. The cursor should
   change, the card should follow without lag, and nothing should jump.
4. **Send to back.** Double-click dead space; the widget should sit behind your
   windows and still be there. Then check double-clicking the *progress bar*
   does **not** send it back — that is the `isInteractive` exclusion, and
   getting it wrong reads as the widget vanishing at random.
5. **The close button's choice.** It must offer Send to back / Quit, not act
   silently. Anchor's set the window level with no indication and read as a
   broken quit.
6. **Two displays.** Drag the widget to a second screen, sleep and wake, unplug
   it. The clamp should keep it reachable. Untested — there is one display
   attached at the time of writing, and **check what is plugged in before
   declaring this untestable**, because Anchor's notes record two sessions that
   wrote "needs a monitor" while one was connected.

## Desktop player

- **Hover with `hoverGrowsWidget` off.** The revealed element must simply have
  to fit; nothing should move.
- **Hover growth near the bottom of the screen.** The card grows downward. At
  the very bottom of a display the clamp will pull it up instead — confirm it
  does not end up half off-screen.
- **Resize while hovering.** Growth is suppressed during a drag (`isResizing`).
  Confirm the card does not fight the pointer.
- **Shrink to the minimum and back.** Elements drop in priority order and must
  come back in the same order. Nothing should flicker in and out at a single
  drag step — the solver is monotone in height and that is asserted, but the
  window-level interaction is not.

## Regressions worth re-checking after any change to `PlayerPanel`

Both of these were real, and both were found only by driving the running app.

- **The tracking area must not be rebuilt inside its own callback.** It was, and
  the app segfaulted in `objc_retain` the first time the pointer entered the
  window — `mouseEntered` → `setHovering` → `relayout` → `setFrame` → rebuild.
  It is now installed once and `.inVisibleRect` keeps it in sync.
- **Resize must be handled in `sendEvent`, not `mouseDown`.** The content is an
  `NSHostingView` and SwiftUI consumes mouse events inside it, so an
  `NSPanel.mouseDown` override never runs for a click on the card. The right
  edge appeared to work because it lands on transparent padding; the bottom edge
  silently did nothing.
- **Cocoa's y grows upward.** Dragging the bottom edge up must shorten the
  window. The opposite sign looked identical to "the drag does nothing",
  because it grew a budget that is capped at the height the layout needs.

## Permissions

| Feature | Needs | State |
|---|---|---|
| Reading playback from Music / Spotify / Amazon | Apple Events | prompts on first use |
| The audio visualiser element | audio-capture | entitlement declared, unexercised |
| Lock-screen surfaces (Phase 4) | none, but uses private SkyLight API | not built |

**TCC grants bind to the code signature, not the bundle id.** An ad-hoc signed
Debug build does not inherit them, so anything gated on a permission can only be
tested in a signed build.

## Measuring

`scripts/measure.sh VinylPod 180 "<label>"`. **Not yet run** — there is no
figure for VinylPod in this repo, and one should not be quoted until there is.

Let it settle **12+ minutes** before believing any RSS number, check the sample
count, and never sample during a build or while doing anything else on the
machine.

## Running alongside Anchor

Both apps draw a desktop widget and a lock-screen panel. Turn Anchor's off while
testing:

```bash
defaults write com.arronlingham.Anchor enableLockScreenMediaWidget -bool false
defaults write com.arronlingham.Anchor enableVinylWidget -bool false
```
