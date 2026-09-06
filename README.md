# Cadence

A native macOS music player. One playback core drives four surfaces — a
lock-screen widget, a lock-screen full-screen player, a launcher widget and a
free-floating desktop player — and each one has its own layout you compose by
hand from the same set of elements.

> **Status: it builds and runs.** The desktop player and both lock-screen
> surfaces work; the layout editor works. **It has never been tested against
> real playback** — every check so far ran against an empty player or a frozen
> sample — and nothing has yet been seen above a real lock screen. See
> `MANUAL-TESTS.md` for what still needs a person.

## The idea

Most now-playing widgets give you one fixed arrangement. Cadence gives you a
**snap grid** per surface and 24 placeable elements — artwork, title, artist,
album, transport, shuffle, repeat, seek, progress bar, elapsed and remaining
time, lyrics, output device, AirPlay, volume, visualiser, app icon, explicit
badge, wall clock, timer — and lets you put them where you want, independently
on every surface.

- **Vinyl or album cover**, with or without the stylus arm, with the progress
  bar optionally running around the record.
- **Resize the desktop player with the mouse.** Elements drop out in a priority
  order you set once, rather than squashing.
- **Hover reveals more.** Mark an element hover-only; the widget grows only if
  what you revealed doesn't fit — an overlaid play button costs no space, a
  progress bar needs a row.
- **Arrange it in a live preview** that is the real player, not a diagram, with
  undo and keyboard nudging.

## Requirements

macOS 26+, Apple Silicon.

## Sources

Now Playing (every app), Apple Music, Spotify, YouTube Music, Amazon Music.

## Building

```bash
xcodebuild -project Cadence.xcodeproj -scheme Cadence -configuration Release \
  -destination 'platform=macOS,arch=arm64' build
```

## Checking it

| | |
|---|---|
| `tests/run_gridsolver_tests.sh` | 93 assertions on the layout engine, compiling the real source |
| `tests/run_runtime_stress.sh` | **live** — hostile settings and malformed layouts against the running app |
| `scripts/audit-reachability.sh` | finds settings, notifications and elements no user can reach |
| `scripts/check-debug-hooks.sh` | asserts the debug hooks are compiled out of Release |
| `scripts/measure.sh` | CPU and RSS sampler |

Every guard in those was proved non-vacuous by breaking the thing it checks and
watching it go red. The results are recorded in each file.

Idle cost, Release, after a 13-minute settle: **0.01% CPU, median 0.00, 12.5 MB**.

## Licence

GPL-3.0. Cadence derives from Anchor, itself derived from Atoll and
boring.notch; the audio spectrum processor derives from rtaudio and FineTune.
See `LICENSE` and `NOTICE` — the copyright headers on ported files are preserved
as the GPL requires.

Not affiliated with or endorsed by the Atoll or boring.notch projects.
