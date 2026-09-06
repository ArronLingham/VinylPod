# Tests for you to run

Everything that could be checked from a script has been. These are the things
that need a person, a password, or hardware — ordered so the ones that could
invalidate the most work come first.

Tick as you go. If something fails, the file to look at is named.

---

## 1. Playback — do this first

**Nothing in this repo has ever seen a real track.** Every check so far ran
against `MusicManager`'s placeholder (`I'm Handsome` / `Me` / `Self Love` —
those strings are its defaults, not a bug) or against the editor's frozen
sample. If the controller layer is wrong, some of what is built on top of it is
wrong too, so this is the highest-value hour you can spend.

There is an **Automation permission dialog still open on your screen** from my
attempt at this. Allow it, or dismiss it and let VinylPod prompt you itself.

- [ ] Play something in **Apple Music**. Title, artist, album and artwork all
      correct in the desktop player?
- [ ] Does the progress bar advance smoothly, and do the times count up and
      down correctly?
- [ ] Press play / pause / next / previous **on the widget**. Does the music
      respond?
- [ ] Does the record start turning on play and **hold its position** on pause,
      rather than snapping back to the top?
- [ ] Drag the progress bar. Does it seek?
- [ ] Repeat with **Spotify**. Then switch source in Settings → Player and
      confirm it follows.
- [ ] Play a **live stream** (a radio station) if you can find one. This is the
      one that crashed Anchor: a live stream reports a NaN duration and
      `Int(NaN)` traps. The times should read `--:--`, not crash.

*If artwork colour looks wrong:* `MusicManager.calculateAverageColor` →
`prominentOpposingColors` in `Sources/Extensions/NSImage+Extensions.swift`.

## 2. The lock screen

Needs your password, which is why I could not do it.

- [ ] Turn it on: Settings → Player → **Show on the lock screen**.
- [ ] Lock the screen (⌃⌘Q). **Does the widget actually appear?** This is the
      SkyLight delegation and it is completely unverified —
      `CGShieldingWindowLevel` alone clears ordinary windows but not
      loginwindow's shield.
- [ ] Double-click the artwork. Does it expand to the full-screen player?
- [ ] Double-click again. Does it collapse?
- [ ] Unlock. **Are both gone?** If one lingers, the unlock notification was
      late and the 500 ms poll in `LockScreenManager` did not catch it.
- [ ] Lock and unlock three or four times in a row. Anything left behind, or
      any crash? SkyLight is a private API and Anchor's notes say closing the
      window rather than ordering it out crashes it.

*If nothing appears:* `Sources/LockScreen/LockScreenPanelManager.swift`, the
`SkyLightOperator.delegateWindow` call.

## 3. Does the desktop player feel right?

Correctness here is measured; this is about whether it is pleasant.

- [ ] Grab each edge and corner and resize. Does the cursor change? Does the
      card follow without lag?
- [ ] Drag the **bottom** edge up. Elements should drop out in priority order —
      album first, then times, then artist. Does the order feel right, or do
      you want to reorder it in the editor?
- [ ] Shrink to the minimum and grow back. Does everything return in the same
      order, with nothing flickering in and out at a single drag step?
- [ ] Hover the card. If you have marked anything hover-only, does the reveal
      feel good or gimmicky? **`hoverGrowsWidget` turns the growth off** if it
      is the latter — it was built with that in mind.
- [ ] Double-click empty space. Does it go behind your windows?
- [ ] Now double-click the **progress bar**. It must *not* go behind — that is
      the `isInteractive` exclusion, and getting it wrong reads as the widget
      vanishing at random.
- [ ] Click the ✕. Does it offer *Send to back* and *Quit*, rather than acting
      silently?

## 4. The layout editor

Settings → Layout. Dragging is verified to persist; these are the edges.

- [ ] Drag an element onto an **occupied** cell. It must refuse — a no-op is
      correct, because two base elements sharing a cell is the grid's one
      invariant.
- [ ] Drag one **below the last row**. That should make a new bottom row.
- [ ] Add every element from the palette in turn and confirm each draws
      something real. **`Output`, `AirPlay`, `Volume` and `Timer` were inert
      icons until this session** and are the most likely to regress.
- [ ] Set an element to **On top** + **On hover**, then turn on *Show hover
      elements*. The surface must **not** grow. Switch it to **In the grid** and
      it must. That is the whole hover model in one test.
- [ ] Set something to priority 0 and shrink the desktop player to its minimum.
      It must survive.
- [ ] **Reset this surface** — does it come back exactly as shipped?
- [ ] Change the desktop layout, then switch to Lock screen widget. **Is it
      untouched?** The four surfaces are meant to be completely independent, and
      this is the requirement most likely to have been broken by a shortcut.

## 5. The audio elements

- [ ] Place **Output** on a surface. Does the menu list your real devices, and
      does picking one switch the Mac's output?
- [ ] Place **Volume**. Does the slider move the system volume, and does it
      show the right level when it first appears?
- [ ] Place **AirPlay** while Apple Music is playing. Does it list your AirPlay
      devices? *(Untested — needs an AirPlay device on your network.)*
- [ ] Place **Timer**, right-click it, pick 1 min. Does it count down and stop?
- [ ] Place **Visualiser**. Does it react to sound? This one acquires the
      CoreAudio process tap, so also check the CPU cost while it is on screen —
      that path cost Anchor 12× its idle CPU when it was left running.

## 6. Two displays

I have not tested any of this; there is one screen attached here.

- [ ] Drag the player to a second display. Does it stay there?
- [ ] Unplug that display. Does the player come back onto the remaining one, or
      is it stranded off-screen? (`clampOnScreen` should catch it.)
- [ ] Sleep and wake. Is it still there and still correct?
- [ ] Lock the screen with two displays attached. Which one does the widget
      appear on, and is that the one you wanted?

## 7. The things added last

- [ ] **Nothing playing.** With no music app running the player should say
      "Nothing playing", show a blank record, blank artist and album, `--:--`
      for both times, and a neutral dark card — **not** a pink card reading
      "I'm Handsome / Me / Self Love". That was Anchor's placeholder joke and it
      reached the screen as a fabricated track.
- [ ] **Then start playing.** It should fill in without a relaunch.
- [ ] **Open at login.** Settings → Player → General. In a Debug or ad-hoc
      build this correctly reads "Unavailable for this build"; it only works
      from a properly signed app in /Applications. Turn it on there, log out and
      back in.
- [ ] **The app icon.** A record on a purple-to-pink plate, in the Dock while
      Settings is open and in Finder. Regenerate with
      `swift scripts/make-icon.swift Sources/Assets.xcassets/AppIcon.appiconset`
      if you want to change it — it is drawn in code, not a binary blob.

## 8. Living with it

The things a short test cannot find.

- [ ] Leave it running for a day. Does memory stay flat? Re-run
      `scripts/measure.sh VinylPod 180 "after a day"` and compare.
- [ ] Quit and relaunch. Is the player where you left it, at the size you left
      it, with your layout intact?
- [ ] Log out and back in. Same.
- [ ] Run it alongside Anchor. Turn Anchor's equivalents off first or you will
      get two of everything:
      ```bash
      defaults write com.arronlingham.Anchor enableLockScreenMediaWidget -bool false
      defaults write com.arronlingham.Anchor enableVinylWidget -bool false
      ```

---

## Known-unfinished, so don't report these as bugs

- **The launcher widget is not reachable.** It is built and uses the same
  engine, but VinylPod has no launcher — it gets wired up when this folds into
  Anchor.

- **No updater**, deliberately. Anchor's Sparkle channels all point at upstream
  Atoll's appcast and once replaced Anchor with upstream.
- **The desktop card's artist and album sit side by side.** That is faithful to
  how `VinylWidgetView` draws its combined subtitle, transcribed into the grid.
  If you dislike it, delete `album` in the editor — the source falls back to
  bare artist too.
