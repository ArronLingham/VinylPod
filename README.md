# VinylPod

A native macOS music player. One playback core drives four surfaces — a
lock-screen widget, a lock-screen full-screen player, a launcher widget and a
free-floating desktop player — and each one has its own layout you compose by
hand from the same set of elements.

> **Status: early.** The source is extracted and the design is settled; the app
> does not build yet. See `CLAUDE.md` for the full specification and
> `EXTRACTION.md` for what came from where.

## The idea

Most now-playing widgets give you one fixed arrangement. VinylPod gives you a
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
  what you revealed doesn't fit.
- **Arrange it in a live preview** that is the real player, not a diagram.

## Requirements

macOS 26+, Apple Silicon.

## Sources

Now Playing (every app), Apple Music, Spotify, YouTube Music, Amazon Music.

## Licence

GPL-3.0. VinylPod derives from Anchor, itself derived from Atoll and
boring.notch; the audio spectrum processor derives from FineTune. See `LICENSE`
and `NOTICE` — the copyright headers on ported files are preserved as the GPL
requires.

Not affiliated with or endorsed by the Atoll or boring.notch projects.
