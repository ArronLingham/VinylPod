# Reference — not built

These files came across in the extraction but are coupled to Anchor's notch or
lock-screen surfaces and are **not in the VinylPod target**. They are kept
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
