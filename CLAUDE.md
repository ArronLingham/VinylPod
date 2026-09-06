# Cadence

A native macOS music player. One playback core drives **four independent
surfaces** — a lock-screen widget, a lock-screen full-screen player, a launcher
widget and a free-floating desktop player — and every one of them has its own
layout that the user composes by hand.

Built from music code extracted out of [Anchor](https://github.com/ArronLingham/Anchor)
(private). Developed standalone, then folded back into Anchor once mature. That
end state is the reason for several decisions here: shared types stay
Anchor-compatible, and nothing depends on a Cadence-only process.

## How to work with me

**Don't narrate.** Do the work, then report the outcome. No running commentary,
no "now I'll do X", no explaining tool calls before making them. Skip preamble
and postamble.

**Surface decisions, not process.** When you need input, state the choice in one
or two lines with a clear recommendation. Don't present an exhaustive survey of
options — pick one and say why in a sentence.

**Report at the end, briefly.** What changed, what broke, what's next. Numbers
and file paths over prose. If something failed, say so plainly with the error.

**Ask before:** anything outward-facing (pushing, publishing, releases),
installing tooling, or deleting code that isn't obviously dead. Local edits,
builds and measurements need no confirmation.

**Don't ask about:** which file to edit, whether to run a build, formatting
choices, or anything this file already settles.

---

## The four surfaces

They share the playback core and the layout engine. They share **nothing else** —
in particular each has its own saved layout, and a change to one must never move
an element on another. This was stated explicitly and repeatedly in the spec; it
is the single requirement most likely to be got wrong, because the code this was
extracted from does the opposite (one global `musicControlSlots` key that every
surface reads).

### 1. Lock screen — small widget player

Toggle-able. Liquid glass. Its own element set.

### 2. Lock screen — full-screen player

Toggle-able. Its own element set, separate from the small widget's.

- Background: choose **blurred album cover** or **a flat blur of the album
  cover's colour**.
- Lyrics can be turned off, which centres the artwork as the focus.
- Artwork: choose **album cover** or **vinyl**; vinyl is with or without the
  stylus arm; the progress bar can run **around** the vinyl (a setting).

### 3. Launcher widget

A now-playing widget living in Anchor's Option+Space launcher.

- **Connected to the real player** — a live view of the same state, not a
  separate mini-player.
- Buttons either **always visible** or **revealed on hover** (a choice).
- Several **fixed** sizes.
- Artwork: album cover or vinyl, vinyl with or without stylus, progress ring
  around the vinyl optional.
- **Clicking it opens the player.**

Cadence has no launcher of its own, so this surface is **built now and wired up
at Anchor integration**. Build it against the same engine and the same layout
slot as everything else; the only missing piece is the host.

### 4. Desktop music player widget

The main surface, and the one with the most new interaction.

- **Close button offers a choice**: send to back, or quit the player. Not a
  silent action.
- Artwork: album cover or vinyl; vinyl with or without stylus; progress ring
  around the vinyl optional.
- Its own element set, separate from all three others.
- **Desktop mode**
  - **Double-clicking dead space** (not the artwork, not a button, not a
    slider) sends the player to the back.
  - Buttons and information are positioned by the user, by dragging them in a
    settings preview.
  - Wall clock and countdown timer are placeable elements like anything else.
- **Mouse-resizable.** The arrangement and content change with size — see
  *Priority* below.
- **Quick access to player settings** from the widget itself.
- **Hover reveals more.** Which elements appear on hover is chosen per element;
  whether the widget grows is *derived*, not configured — see *Hover* below.

---

## The layout model

This is the centre of the app. Everything above is an instance of it.

### Why the extracted code cannot just be extended

`MusicControlButton` (now `Reference/MusicControlButton.swift`) is a **fixed
5-slot array of buttons** on **one global Defaults key**. Progress bar, title,
artist, album, elapsed and remaining time and the artwork itself are not in that
enum at all — they are hardcoded `VStack` children on every surface, with at most
a boolean to hide them. The renderer that consumes the slots is copy-pasted into
three files in Anchor and hardcoded outright in two more.

So it was replaced wholesale, not extended. It has been retired to `Reference/`
along with its `musicControlSlots` key — a live `Defaults` key backed by a type
nothing draws from is a dead switch by this file's own definition.

### Elements

Every placeable thing is one `PlayerElement` case. All 24 exist as data on
`MusicManager` or as components already in this tree — nothing here needs a new
data source.

| Group | Cases |
|---|---|
| Artwork | `artwork` (style: cover \| vinyl) |
| Text | `title`, `artist`, `album` |
| Transport | `playPause`, `next`, `previous`, `seekBackward`, `seekForward` |
| Modes | `shuffle`, `repeatMode` |
| Progress | `progressBar`, `timeElapsed`, `timeRemaining`, `trackTimeToggle` |
| Audio | `outputDevice`, `airPlay`, `volumeSlider`, `visualizer` |
| Extras | `lyrics`, `appIcon`, `explicitBadge`, `clock`, `timer` |

`trackTimeToggle` is one time readout that flips between elapsed and remaining
when clicked. `clock` is the wall clock, `timer` the countdown — both
independent of playback, both placeable anywhere.

**`artwork` carries the style, and that is deliberate.** Cover-vs-vinyl,
stylus-on-off and progress-ring-on-off are properties of one element, so they are
expressed once and work identically on all four surfaces. The extracted code has
these as four loose global booleans (`vinylShowStylus`, `vinylShowTitle`,
`vinylShowProgress`, `vinylProgressStyle`) that apply everywhere at once; those
are superseded.

### Placement: a snap grid

Each surface is a coarse grid. An element occupies a cell and may span columns.

```
Desktop player - 6 x 4

+--------------------------------------+
|  ______                              |
| |      |  Title...........           |
| | ART  |  Artist..........           |
| |______|                             |
| ###### progress (span 6) ##########  |
|   .  [<<] [>||] [>>]  .  0:42  -2:15 |
+--------------------------------------+
```

- **Drag snaps to a cell.**
- **Overlaps are refused** by the engine, not merely discouraged.
- **Spans scale on resize**, so an arrangement stays sane at any size.

A free canvas was considered and rejected. Elements have genuinely different
shapes — a button is 1x1, a progress bar wants the whole row, a title is one row
of variable width, artwork is a square block — and text and buttons do not scale
with the window. Exact x/y positions collide the first time the widget is
resized, and the user would then be re-fixing the layout at every size. The grid
buys real positioning without that failure.

`ElementMetrics` per case: `minSpan`, `preferredSpan`, `rowSpan`,
`growsHorizontally` (text and progress absorb spare width), `isInteractive`
(excluded from double-click-to-send-back hit testing).

### Priority: what disappears as it shrinks

Every placement carries a `priority`. As the widget shrinks, the engine drops the
**lowest-priority** elements first and recompacts. One ordering the user
maintains once, working at any size — rather than four breakpoint layouts to keep
in sync.

Hover reuses this exact mechanism. There is one dropping rule in the codebase.

### Hover: growth is derived, never configured

Each placement is marked `.always` or `.onHover`.

```
PAUSE ON HOVER - fits, no growth
+-------------+      +-------------+
|   ______    |      |   ______    |
|  |      |   |  ->  |  | [>||]|   |
|  |______|   |      |  |______|   |
|   Title     |      |   Title     |
+-------------+      +-------------+

PROGRESS ON HOVER - needs a row, grows
+-------------+      +-------------+
|   ______    |      |   ______    |
|  |      |   |  ->  |  |      |   |
|  |______|   |      |  |______|   |
|   Title     |      |   Title     |
+-------------+      | ### prog ###|
                     +-------------+
```

The engine solves the hover set at the resting width and grows the window **only
if it does not fit**. A pause button overlays the artwork, so nothing moves. A
progress bar needs its own row, so the widget grows by one row. The user never
sets a hover size.

Growth sits behind `hoverGrowsWidget`, default on. It was flagged as possibly
too gimmicky in practice — if it reads that way in use, turn it off and the
hover set simply has to fit. Do not delete the mechanism on that basis without
being asked.

### Storage

```swift
Key<PlayerLayouts>("playerLayouts")     // one key, four independent layouts
```

One atomic write, one migration, and it is structurally impossible for two
surfaces to end up sharing a layout by accident. Each ships a default built from
what the corresponding hardcoded surface draws today.

### The settings editor

Surface picker → live preview → element palette → per-element inspector
(visibility, priority, span).

**The preview is the real surface.** Real glass, real album tint, an actually
spinning record, with a drag layer over the top. It is bound to a **frozen sample
track** — fixed artwork, a deliberately long title so truncation is visible, a
3:42 duration — so the layout does not shift under the cursor when a track
changes, and long-title behaviour is visible without waiting for one to play.

Anchor's `MusicSlotConfigurationView` draws grey rounded rects instead, which
cannot show glass, tint, artwork or true proportions. Its *drag mechanics* are
still worth copying: `NSItemProvider` string payloads, a trash drop target,
tap-to-place into the first free cell, reset-to-default. So is
`LauncherGridView`'s `ReorderableCell` modifier and the comment explaining why
attaching `.draggable` to one branch of an `if` breaks cell identity mid-drag.

---

## Project constraints

- **Low CPU is the top priority.** Measure before and after any perf change;
  record idle CPU% and RSS. Never add a polling loop where an event-driven API
  exists.
- **Native Swift only.** No Electron, no Node, no sidecar processes.
- **macOS 26+ / Apple Silicon only.** `MACOSX_DEPLOYMENT_TARGET = 26.0`,
  arm64-only. Chosen to keep the public `glassEffect` API and to guarantee a
  clean fold-back into Anchor. It is a restrictive floor for a public repo and
  that was accepted knowingly.
- **The four surfaces share the engine and nothing else.** Any change that makes
  one surface's settings affect another is a bug, however convenient.

### Three rules carried over from Anchor, each learned the hard way

- **Reference-count anything periodic.** `AudioTap` is `acquire()`/`release()`,
  built on 0→1 consumers and torn down on 1→0. It used to start at launch and
  run all session to feed a view that is on screen occasionally; fixing that was
  worth **12x** Anchor's idle CPU (0.95% → 0.08%).
- **Schedule, don't poll.** Compute when the next thing is due and sleep exactly
  that long.
- **A loop that no-ops is still a loop.** Anchor's lyric task was gated on the
  feature flag but not on whether anything could change, and woke once a second
  against paused playback for 0.24% of a core. Gate on the work existing, not on
  the feature being on.

---

## Licensing — a one-way door

**This repo is public and GPL-3.0.** That is a decision already taken, and it
cannot be undone once the code is forked or archived.

Every extracted file carries a GPL-3.0 header from the chain
boring.notch → Atoll → Anchor. `Sources/Visualizer/AudioProcessor.*` traces to
FineTune (GPL-3.0, © 2026 Ronit Singh). Publishing is distribution, so copyleft
applies: the repo is GPL-3.0 and anyone may use, modify and redistribute it.

**Never strip a copyright header from a ported file.** The GPL requires they be
preserved; only the title line above one belongs to this project. `NOTICE`
records the full chain and must stay accurate as more code is ported.

Do not let Sapphire source in — it is AGPL-3.0 and would bind this to the
stricter licence.

---

## Source layout

```
Cadence/
  Sources/
    Core/            MusicManager, PlaybackState, MediaChecker      (the model)
    MediaControllers/  five sources + Spotify auth
    Layout/          PlayerElement, SurfaceLayout, GridSolver,      (the engine)
                     ElementMetrics, PlayerSurfaceView
    Player/          PlayerWindowManager                            (desktop widget)
    Settings/        LayoutEditorView, SampleTrack
    Vinyl/           VinylRecordView, VinylWidgetView, window manager
    Visualizer/      AudioTap, RealTimeAudioSpectrum, AudioProcessor (C++)
    Lyrics/          SyncedLyricsList, NotchLyricsView, LyricsTranslator
    Artwork/         AnimatedArtworkManager, ImageService
    Overlay/         control overlay, marquee, live-stream progress
    Routing/         AudioRouteManager, AirPlay, Bluetooth
    Support/         MusicTypes, MusicDefaults, AppleScript helpers
  tests/             shell harnesses, no test target needed
  scripts/measure.sh CPU/RSS sampler
```

`Sources/Support/MusicTypes.swift` and `MusicDefaults.swift` were **generated by
the extraction**, not copied — the four music enums and the 73 Defaults keys the
extracted files actually reference, lifted out of Anchor's 412-key
`Constants.swift`. That started at 73 and is now **38**:
`scripts/audit-reachability.sh` found 35 that nothing referenced at all — Anchor
settings for the notch UI, six system HUDs, the camera mirror, per-app audio and
Bluetooth announcements, every one a switch a user could flip to no effect.

---

## Playback sources

All five controllers come across, all event-driven except one fallback:

| Controller | Mechanism |
|---|---|
| `NowPlayingController` | private MediaRemote — covers every app |
| `AppleMusicController` | AppleScript |
| `SpotifyController` | AppleScript + Web API (SP_DC cookie for lyrics/Canvas) |
| `YouTubeMusicController` | WebSocket, with a **2 s poll fallback** when unavailable |
| `AmazonMusicController` | AppleScript |

`MusicManager` publishes 27 properties. Progress is drawn with a `TimelineView`
interpolating locally from `elapsedTime` + `timestampDate` + `playbackRate` — it
does **not** need a publish per frame, and adding one would be a regression.

The Spotify `SP_DC` cookie is user-supplied at runtime. **It must never be
committed**, and this is a public repo.

---

## Gotchas already known to bite in this code

Each of these cost real time in Anchor. They are inherited verbatim with the
files.

- **`CALayer.contents` set from an `NSImage` honours neither `contentsGravity`
  nor the layer's corner radius.** The square album cover sat on a round record
  until it was converted to a `CGImage` and masked with a `CAShapeLayer`.
  `VinylRecordView` does both belt and braces; keep them.
- **`layout()` must run inside a `CATransaction` with actions disabled**, or the
  record visibly swells every time the window moves between displays.
- **The record is CALayers, not SwiftUI, and that is load-bearing.** A SwiftUI
  rotation is a per-frame main-thread transaction; a `CABasicAnimation` is handed
  to the render server once. It is *removed* on pause, not left running at zero
  speed.
- **A borderless panel must be given its content view at `init`.** Assigning
  `contentView` afterwards can leave it with no backing store, never reaching the
  window server while still reporting `isVisible == true`.
- **`Int(someDouble)` traps on NaN, and a live stream reports a NaN duration.**
  Anchor took a SIGTRAP drawing elapsed time over live content. Guard
  `isFinite` before any time formatting.
- **Height must be derived from what is drawn.** `VinylWidgetSize.height(...)`
  was a fixed 1.36 ratio, so turning the progress bar off left an empty strip.
  `GridSolver` generalises the corrected version.
- **`keptOnScreen` exists because resizing keeps the origin.** Small→Desktop
  (190→560pt) near a screen edge pushed a borderless panel off screen, and one
  you cannot see is one you cannot drag back. Mouse resize must apply the same
  clamp.
- **`vinylBackgroundOpacity` is currently dead.** `VinylWidgetView.swift:240`
  reads `.opacity(cond ? 1 : 1)` — both branches identical — so the slider and
  the five-step context menu do nothing. Fix when that view is converted.
- **`MusicManager` still calls `AnchorViewCoordinator` at :1199-1201.** Two
  sneak-peek lines into Anchor's notch, which does not exist here. **Done** —
  it posts `.cadenceTrackDidChange` instead, and nothing observes that yet.

### And the meta-lesson from Anchor, which applies to every feature here

A feature can be complete, tested and installed while being **unreachable**.
Anchor shipped this repeatedly: settings tabs missing from a hardcoded sidebar
array, `Defaults` keys referenced only by their own manager (no UI) or only by
their own pane (no consumer), notifications posted that nothing observed, and
shortcuts with handlers but no recorder row. After building anything, check the
whole path: **is it stored, is it read, is it rendered, and can the user reach
it?**

Related: **a guard no negative control can break is not a guard.** Delete it and
re-run the tests — if they still pass, it was inert. Anchor shipped a safety
check that was provably dead, twice.

---

## Status

| Phase | State |
|---|---|
| 0 — repo, project, CLAUDE.md | **done** |
| 1 — the extraction builds | **done**; 0 errors, launches, status item verified via AX |
| 2 — layout engine | **done**; `GridSolver` + four defaults |
| 3 — desktop player | **done**; renders, resizes, hovers, sends to back |
| 4 — lock screen | **built**; both surfaces render. Unverified above a *real* lock screen |
| 5 — launcher widget | **built**, not reachable until Anchor integration |
| Layout editor | **done**; drag-to-arrange with a live preview |

`TESTING.md` records what is proven and what still needs a person. The headline
gap: **nothing here has yet seen a real track** — every check so far ran with
nothing playing.

`Reference/` holds nine extracted files that are coupled to Anchor's notch or
lock screen and are **not in the target**. `Reference/README.md` says what each
is worth porting for. Do not add one to the build without resolving the coupling
it lists.

## Checking it

Five harnesses, and **every guard in them was proved non-vacuous** by breaking
the thing it checks and watching it go red. The controls and their measured
results are recorded in each file. That step is not optional here: this repo has
already produced one test that read correctly, named the right property, and
could not fail.

| | |
|---|---|
| `tests/run_gridsolver_tests.sh` | **93 assertions**, compiling the real `Sources/Layout/*.swift` |
| `tests/run_runtime_stress.sh` | **live** — hostile settings and malformed layouts against the running app |
| `scripts/audit-reachability.sh` | dead switches, unreachable settings, orphaned notifications, undrawn elements |
| `scripts/check-debug-hooks.sh` | asserts `CADENCE_*` is absent from Release **and present in Debug** |
| `scripts/measure.sh` | CPU and RSS |

Run the reachability audit after adding a setting, an element or a notification.
It finds the failure this project inherits and keeps re-learning — code that is
written, correct and tested, and that no user can reach. Its allowlist is the
record of which keys legitimately have no UI, and why; adding to it is a
decision, not a formality.

## Build

```bash
xcodebuild -project Cadence.xcodeproj -scheme Cadence \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" build
```

Release uses the real identity
(`Apple Development: arronlingham@icloud.com (Q4FNFX8QSH)`, team `KLWHJX56T3`).

**TCC grants bind to the code signature, not the bundle id** — an ad-hoc signed
Debug build does not inherit them. Anything gated on a permission can only be
tested in a signed build.

**No Sparkle.** Anchor's updater channels all point at *upstream Atoll's*
appcast, and a live updater there once replaced Anchor with upstream. Don't
bring it across.

## Measuring

```bash
scripts/measure.sh Cadence 180 "<label>"
```

- **Let it run 12+ minutes before believing any RSS figure.** Anchor recorded
  82.5 MB from an app that actually settled at 18.5 MB. Flat samples do not mean
  settled.
- **Check the sample count.** Two figures in Anchor's history were quoted from
  runs of 7 and 15 samples; a short window cannot see the tail and looks like a
  quiet app.
- **Never sample during a build**, or while doing anything else on the machine.
- The script samples `cputime` over elapsed wall time. Do not "simplify" it to
  `ps -o %cpu`, which is a lifetime average.

## Testing

Shell harnesses that compile the real source with `swiftc`, following Anchor's
`tests/run_*.sh` — no test target, and they cannot drift from the
implementation. `GridSolver` is pure (no SwiftUI, no `Defaults`) specifically so
it can be tested this way.

**Prove every guard non-vacuous by breaking it first** and watching the harness
go red. A harness that cannot fail is worse than none.

---

## Anchor integration (the end state)

Cadence folds back into Anchor once mature. To keep that cheap:

- Keep `PlayerElement`, `SurfaceLayout` and `GridSolver` free of Cadence-only
  types, so Anchor's notch player becomes a fifth surface rather than a rewrite.
- The launcher widget targets Anchor's `WidgetCard` shell
  (`minWidth: 108, minHeight: 62`, `.regularMaterial`, 14pt radius) and replaces
  `LauncherVinylWidget`'s static, non-spinning 38pt circle.
- Preserve the GPL headers exactly — Anchor needs them too.

**While developing, turn Anchor's lock-screen widget off.**
`enableLockScreenMediaWidget` defaults to **true**, so with both apps running
there will be two lock-screen panels competing for the same space:

```bash
defaults write com.arronlingham.Anchor enableLockScreenMediaWidget -bool false
```

The same applies to `enableVinylWidget` once Cadence's desktop player works.
