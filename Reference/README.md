# Reference — not built

These files came across in the extraction but are coupled to Anchor's notch or
lock-screen surfaces and are **not in the Cadence target**. They are kept
because each contains logic worth porting rather than reinventing, and because
deleting them would lose the record of how Anchor solved these problems.

| File | Coupled to | Why it's worth keeping |
|---|---|---|
| `MinimalisticMusicPlayerView.swift` | 13 notch types (sliders, popovers, timer, brightness/volume controllers) | The most complete player layout in the extraction. Harvest the arrangement when building surface defaults. |
| `MusicSupplementViews.swift` | `TimerManager`, `FocusModeType`, reminders | The clock/timer element rendering. |
| `MusicControlWindowController.swift` | `AnchorViewModel`, `ContentView`, `LockScreenManager` | **Per-display window management** — one controller per screen, `boundScreen` recorded at present time. Anchor's notes record this as a real bug fixed the hard way. |
| `MusicControlWindowManager.swift` | `AnchorViewModel`, `ContentView` | `manager(for:)` keyed by `NSScreen.localizedName`, plus `pruneDetachedScreens()`. Same lesson. Also the hover-grow animation timings (0.24s in / 0.16s re-sync) the desktop player will copy. |
| `FullScreenArtworkWindowManager.swift` | `LockScreenManager`, `LockScreenPanelManager` | 1,807 lines. Replaces the actual desktop wallpaper with a pre-blurred album image, and installs a live wallpaper for Spotify Canvas. Read before building the full-screen player. |
| `SettingsMedia.swift` | 16 settings types | Anchor's media settings pane — a reference for what is configurable, superseded by the layout editor. |
| `BluetoothAudioManager.swift` | `AppDelegate`, `HUD`, `HUDSuppressionCoordinator` | Also **still polls** `IOBluetoothDevice.pairedDevices()` every 15s idle / 3s connected — the largest non-idle main-thread leaf in Anchor. Rewrite to delegate callbacks before bringing it in, and note IOBluetooth blocks on a main-queue semaphore in `init`, which deadlocked Anchor at launch once. |

Do not add these to the target without first resolving the coupling listed above.

| `VinylWidgetView.swift` | superseded | The desktop widget `PlayerSurfaceView` replaces. Its proportional maths is the source the desktop default layout was transcribed from, and `VinylProgressStyle` + `VinylRecordRepresentable` were extracted out of it into `Sources/Vinyl/VinylRecordRepresentable.swift` before it was retired. **Its `vinylBackgroundOpacity` is a dead setting** — `.opacity(cond ? 1 : 1)`, both branches identical. |
| `VinylWidgetWindowManager.swift` | superseded | Replaced by `Sources/Player/PlayerWindowManager.swift`, which keeps its panel setup, frame autosave, `keptOnScreen` clamp and display-sleep teardown. Its five fixed size presets are gone: the player is now freely resizable. |

Retiring these two mattered rather than being tidiness: `enableVinylWidget`
would otherwise have stayed a live Defaults key able to put a *second*,
superseded desktop widget on screen alongside the real one, with no UI saying
so. That is the dead-switch trap in its most literal form.

| `MusicControlButton.swift` | superseded | The five-slot, button-only model on one global key that `PlayerElement` replaces. Kept because `DefaultLayouts.swift` cites its slot positions as the source of the desktop transport arrangement, and because Anchor still uses it — folding Cadence back in means reconciling the two. Its `musicControlSlots` key is gone: a live Defaults key backed by a type nothing drew from is a dead switch by this project's own definition. |

| `LottieAnimationView.swift` | dead + broke Release | Referenced by nothing but itself, and it pulled in LottieUI -> lottie-spm, a **dynamic** xcframework. The hand-written pbxproj has no embed phase, so the Release build launched and immediately died in dyld: `Library not loaded: @rpath/Lottie.framework`. Debug survived because DerivedData's PackageFrameworks happened to be on the runpath. Dropping it removed the dependency rather than adding an embed phase for a framework nothing used. If Lottie is ever wanted, the embed phase has to come with it. |
