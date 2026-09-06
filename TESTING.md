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

## Layout editor

Settings → Layout. The preview is the real `PlayerSurfaceView` bound to
`PlayerSnapshot.sample` — a fixed track with a deliberately long title (so
truncation is visible), a separate album name (so the two text elements are
distinguishable) and 3:42 split 1:18 / -2:24 (so the two time readouts are).

Verified live: the window opens at 820x724, the preview draws the real record
and sample metadata, and **dragging persists** — moving the Previous button
wrote `previous` from column 1 to column 0 in `playerLayouts` and touched
nothing else.

Keyboard, all verified live against the running app:

| Key | Does |
|---|---|
| ⌘Z / ⇧⌘Z | undo / redo, per surface, 50 deep |
| ← → ↑ ↓ | nudge the selection one cell; refused into an occupied cell |
| ⌫ | remove the selection |
| esc | deselect |

Worth checking by hand:

- **Drag onto an occupied cell.** It must be refused, not squeezed in. A no-op
  is correct: two base placements sharing a cell is the grid's one invariant.
- **Drag below the last row.** That makes a new bottom row.
- **Add every element from the palette** and confirm each draws something. Four
  of them (`outputDevice`, `airPlay`, `volumeSlider`, `timer`) were inert icons
  until recently and are the ones most likely to regress.
- **Overlay vs in-the-grid**, in the inspector. Set an element to overlay and
  mark it hover-only; the surface must not grow when the hover preview is on.
  Set it back to in-the-grid and it must.
- **Priority 0** must survive shrinking the desktop player to its minimum.
- **Reset this surface** returns exactly the shipped default.
- **Switch surfaces and come back.** Each of the four is independent; a change
  to one must never move an element on another.

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
| Open at login | none, but needs a signed app outside DerivedData | reports "Unavailable for this build" otherwise |
| The audio visualiser element | audio-capture | entitlement declared, unexercised |
| Lock-screen surfaces | none, but uses private SkyLight API | built, unverified on a real lock |
| Output device / volume elements | none | built, live |
| AirPlay element | Apple Events (Music) | built, unverified |

**A missing usage description is a CRASH, not a prompt.** VinylPod died with
SIGABRT inside `__TCC_CRASHING_DUE_TO_PRIVACY_VIOLATION__` because
`AnimatedArtworkManager` calls `MusicAuthorization.request()` and the Info.plist
had no `NSAppleMusicUsageDescription`. There is no dialog and no error return —
macOS simply kills the process. The crash report names the missing key exactly,
which is the fastest way to diagnose it.

The built tree touches exactly two TCC-gated APIs, and both are covered:
`MusicAuthorization` (`NSAppleMusicUsageDescription`) and
`AudioHardwareCreateProcessTap` (`NSMicrophoneUsageDescription` plus the
`com.apple.security.device.audio-input` entitlement). Re-run that audit when
adding a framework:

```bash
grep -rhoE '^import (MusicKit|EventKit|Speech|AVFoundation|Contacts|Photos|CoreLocation|CoreBluetooth|ScreenCaptureKit)' Sources --include='*.swift' | sort -u
```

**TCC grants bind to the code signature, not the bundle id.** An ad-hoc signed
Debug build does not inherit them, so anything gated on a permission can only be
tested in a signed build.

## Audits

`scripts/audit-reachability.sh` — run it after adding a setting, an element or a
notification. It finds the failure this project inherits and keeps re-learning:
code that is written, correct and tested, but that no user can reach. There is
no build error and no exception, so nothing else catches it.

Four checks, each for a shape that has actually occurred here:

1. A `Defaults` key nothing outside Settings reads — a dead switch.
2. A key no UI exposes — unreachable.
3. A `Notification.Name` posted with no observer, or observed with no poster.
4. A `PlayerElement` case `PlayerSurfaceView` never draws.

**Its first run removed 35 keys.** All were Anchor settings for features
VinylPod does not have — the notch UI, six system HUDs, the camera mirror,
per-app audio, the music control window, Bluetooth announcements — that came
across with the extraction. Every one was a switch a user could flip in a plist
to no effect at all. It also exposed nine settings that were read by code and
had no control, and caught `.mediaControllerChanged` still being observed after
its poster was replaced.

The allowlist in that script is the record of which keys legitimately have no
UI, and why. Adding to it is a decision; a key that is not internal state
belongs in the settings pane instead.

**Proved non-vacuous**, all three checks: adding a key nothing reads, removing a
renderer for a placeable element, and observing a notification nothing posts
each make it fail.

## Findings from the adversarial review that are NOT fixed

A four-agent review ran against the finished code. **Its verification pass never
ran** — all 46 verifier agents died on a spend limit — so every finding below is
a *claim* that was read and judged by hand, not one that survived an independent
refutation. Treat them as leads.

Fixed after checking the code: the AirPlay `1...0` range trap (a hard crash on
the common path), the drag reporting coordinates in the handle's own space, the
drag writing a compacted row index into storage, an overlay dragged off its base
being silently destroyed, Reset becoming unreachable, `.mediaControllerChanged`
and `.systemAudioRouteDidChange` being observed but never posted, `enableLyrics`
and `lockWidgetVerticalOffset` having no UI, `launcherWidgetSize` being dead,
the lock window being an `NSWindow` carrying a panel-only style bit, SkyLight
delegation recording success it had not verified, the immersive overlay having
only a double-click as its exit, the expand gesture covering the whole widget,
the lock poll running with the feature off, the audio elements doing live system
work inside the settings preview, `setArtwork` re-rasterising per render,
`VolumeElement` making HAL calls in a `@State` initialiser, and the window
manager decoding all four layouts from JSON several times per resize event.

**All six were subsequently closed:** the solve is memoised on
(layout, size, hovering) and pinned by six assertions whose negative control
drops the suite to 58/76; the renderer splits into a live body that observes
`MusicManager` and a frozen one that does not; `TimelineView` schedules share a
fixed epoch instead of re-anchoring at `.now`; `PlayerTimer` is
reference-counted the way `AudioTap` is; and the lock panel follows the
menu-bar screen rather than `NSScreen.main` (which is "the screen with the key
window", and while locked there is none) and re-lays-out on
`didChangeScreenParameters`.

**Nothing from the review is knowingly left open.** What remains unverified is
the list under "What only a person can check" — and the review itself was
judged by hand, so a finding it got wrong would have been dismissed by hand
too.

## Measuring

| Build | mean | median | p90 | max | RSS |
|---|---|---|---|---|---|
| Release, idle, 19 min uptime, shipped defaults | 0.01% | 0.00% | 0.00% | 0.48% | 12.5 MB |
| Release, same, after the review fixes | 0.03% | 0.00% | 0.00% | 0.95% | 13.2 MB |
| Release, all fixes + memoisation | 0.01% | 0.00% | 0.00% | 0.47% | 16.2 MB |

86-87 samples each, all after a 13+ minute settle. **All three rows are the same
number.** Every median and p90 is 0.00, so each mean is carried entirely by a
noisy tail, and this project's own rule is not to read a change of less than
roughly 2x as signal. The RSS spread (12.5 / 13.2 / 16.2 MB) is the same story
— do not quote any of these against another as a win or a regression.

What they do establish, together, is a **ceiling**: an idle VinylPod costs
essentially nothing, and none of the review fixes changed that. The memoisation
was for the resize path, which none of these rows measures — that would need a
sampler running during a drag, and there is no figure for it. RSS settled 72 → 28 → 12.5 MB over roughly 20 minutes;
the reading at 5 minutes would have been about six times too high.

That is below Anchor's best recorded row (16 MB) and its best idle CPU (0.03%),
which is what you would expect from an app with one window and no notch.

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
