// Music-related Defaults keys, extracted from Anchor/Models/Constants.swift.
// GPL-3.0. Copyright (C) 2024-2026 Atoll Contributors. See NOTICE.

import Defaults
import Foundation
import SwiftUI

extension Defaults.Keys {
    static let autoHideInactiveNotchMediaPlayer = Key<Bool>("autoHideInactiveNotchMediaPlayer", default: true)
    static let cameraMirrorDeviceID = Key<String>("cameraMirrorDeviceID", default: "")
    static let coloredSpectrogram = Key<Bool>("coloredSpectrogram", default: true)
    static let colorExtractionMode = Key<ColorExtractionMode>("colorExtractionMode", default: .vibrant)
    static let didClearLegacyURLCacheV1 = Key<Bool>("didClearLegacyURLCacheV1", default: false)
    static let enableBrightnessHUD = Key<Bool>("enableBrightnessHUD", default: true)
    static let enableCameraMirror = Key<Bool>("enableCameraMirror", default: false)
    static let enableCircularHUD = Key<Bool>("enableCircularHUD", default: false)
    static let enableCustomOSD = Key<Bool>("enableCustomOSD", default: false)
    static let enableFullscreenMediaDetection = Key<Bool>("enableFullscreenMediaDetection", default: true)
    static let enableHorizontalMusicGestures = Key<Bool>("enableHorizontalMusicGestures", default: true)
    static let enableKeyboardBacklightHUD = Key<Bool>("enableKeyboardBacklightHUD", default: true)
    static let enableLockScreenMediaWidget = Key<Bool>("enableLockScreenMediaWidget", default: true)
    static let enableLyrics = Key<Bool>("enableLyrics", default: false)
    static let enableMinimalisticUI = Key<Bool>("enableMinimalisticUI", default: false)
    static let enablePerAppAudio = Key<Bool>("enablePerAppAudio", default: false)
    static let enableRealTimeWaveform = Key<Bool>("enableRealTimeWaveform", default: false)
    static let enableReminderLiveActivity = Key<Bool>("enableReminderLiveActivity", default: true)
    static let enableSneakPeek = Key<Bool>("enableSneakPeek", default: false)
    static let enableSystemHUD = Key<Bool>("enableSystemHUD", default: true)
    static let enableVerticalHUD = Key<Bool>("enableVerticalHUD", default: false)
    static let enableVolumeHUD = Key<Bool>("enableVolumeHUD", default: true)
    static let enableWaveformScrubber = Key<Bool>("enableWaveformScrubber", default: true)
    static let lightingEffect = Key<Bool>("lightingEffect", default: true)
    static let lockScreenMusicAlbumParallaxEnabled = Key<Bool>("lockScreenMusicAlbumParallaxEnabled", default: false)
    static let lockScreenMusicFullscreenArtworkEnabled = Key<Bool>("lockScreenMusicFullscreenArtworkEnabled", default: true)
    static let lockScreenMusicFullscreenVideoArtwork = Key<Bool>("lockScreenMusicFullscreenVideoArtwork", default: true)
    static let lockScreenUseArtworkLayoutOverFullscreenCanvas = Key<Bool>("lockScreenShowCenteredAlbumArtOverFullscreenCanvas", default: true)
    static let lyricsOffsetSeconds = Key<Double>("lyricsOffsetSeconds", default: 0.2)
    static let lyricsTranslationEnabled = Key<Bool>("lyricsTranslationEnabled", default: false)
    static let lyricsVisibleLines = Key<Int>("lyricsVisibleLines", default: 0)
    static let mediaController = Key<MediaControllerType>("mediaController", default: defaultMediaController)
    static let musicControlSlots = Key<[MusicControlButton]>("musicControlSlots", default: MusicControlButton.defaultLayout)
    static let musicControlWindowEnabled = Key<Bool>("musicControlWindowEnabled", default: false)
    static let musicGestureBehavior = Key<MusicSkipBehavior>("musicGestureBehavior", default: .track)
    static let musicSkipBehavior = Key<MusicSkipBehavior>("musicSkipBehavior", default: .track)
    static let parallaxEffectIntensity = Key<Double>("parallaxEffectIntensity", default: 6.0)
    static let pinnedInputDeviceUID = Key<String>("pinnedInputDeviceUID", default: "")
    static let playerColorTinting = Key<Bool>("playerColorTinting", default: true)
    static let selectedVisualizer = Key<CustomVisualizer?>("selectedVisualizer", default: nil)
    static let showAirPodsListeningModeChanges = Key<Bool>("showAirPodsListeningModeChanges", default: false)
    static let showBluetoothDeviceConnections = Key<Bool>("showBluetoothDeviceConnections", default: true)
    static let showLiveCanvasInDynamicIsland = Key<Bool>("showLiveCanvasInDynamicIsland", default: false)
    static let showMediaOutputControl = Key<Bool>("showMediaOutputControl", default: true)
    static let showMinimalisticBatteryIndicator = Key<Bool>("showMinimalisticBatteryIndicator", default: true)
    static let showPerAppVolumeControl = Key<Bool>("showPerAppVolumeControl", default: true)
    static let showShuffleAndRepeat = Key<Bool>("showShuffleAndRepeat", default: true)
    static let showSneakPeekOnTrackChange = Key<Bool>("showSneakPeekOnTrackChange", default: true)
    static let showStandardMediaControls = Key<Bool>("showStandardMediaControls", default: true)
    // NB: the stored name is not the Swift name. Anchor renamed the property
    // and kept the old string so existing preferences kept working.
    static let sliderColor = Key<SliderColorEnum>(
        "sliderUseAlbumArtColor",
        default: SliderColorEnum.white
    )
    static let spotifyAuthAccessToken = Key<String>("spotifyAuthAccessToken", default: "")
    static let spotifyAuthAccessTokenExpiration = Key<Double>("spotifyAuthAccessTokenExpiration", default: 0)
    static let spotifyAuthLastValidatedAt = Key<Double>("spotifyAuthLastValidatedAt", default: 0)
    static let spotifySPDCCookie = Key<String>("spotifySPDCCookie", default: "")
    static let useMusicVisualizer = Key<Bool>("useMusicVisualizer", default: true)
    static let vinylProgressStyle = Key<VinylProgressStyle>("vinylProgressStyle", default: .bar)
    static let visualizerBarCount = Key<Int>("visualizerBarCount", default: 4)
    static let waitInterval = Key<Double>("waitInterval", default: 3)

    static let notchAnimationProfile = Key<NotchAnimationProfile>("notchAnimationProfile", default: .bouncy)

    static let accentColor = Key<Color>("accentColor", default: Color.blue)

    // MARK: - VinylPod's own keys
    //
    // Everything above is inherited from Anchor. These are new, and each one is
    // read by code outside Settings before it was added -- a key nothing
    // consumes is a dead switch.

    /// The four independent surface layouts, in one value. One atomic write,
    /// one migration, and no way for two surfaces to share a layout by accident.
    static let playerLayouts = Key<PlayerLayouts>("playerLayouts", default: .defaults)

    static let enablePlayerWidget = Key<Bool>("enablePlayerWidget", default: true)
    /// Width only. Height is whatever the layout needs at that width.
    static let playerWidth = Key<Double>("playerWidth", default: 320)
    /// A height the user has dragged to, or 0 for "whatever the layout needs".
    /// When set, the solver treats it as a budget and drops the lowest-priority
    /// elements until the rest fit.
    static let playerHeightBudget = Key<Double>("playerHeightBudget", default: 0)
    static let playerWindowLevel = Key<PlayerWindowLevel>("playerWindowLevel", default: .normal)
    static let playerTintsWithAlbum = Key<Bool>("playerTintsWithAlbum", default: true)
    /// Unlike Anchor's `vinylBackgroundOpacity`, this one is actually applied.
    /// That one reached the view as `.opacity(cond ? 1 : 1)` -- both branches
    /// identical -- so its slider and its five-step context menu did nothing.
    static let playerBackgroundOpacity = Key<Double>("playerBackgroundOpacity", default: 1.0)
    /// Growth on hover. On by default; turning it off means a revealed element
    /// simply has to fit in the resting frame.
    static let hoverGrowsWidget = Key<Bool>("hoverGrowsWidget", default: true)

    /// The small lock-screen widget. Off by default: it draws over the lock
    /// screen through a private SkyLight API, which is not something to switch
    /// on for someone without their say-so.
    static let enableLockScreenWidget = Key<Bool>("enableLockScreenWidget", default: false)
    static let lockWidgetWidth = Key<Double>("lockWidgetWidth", default: 380)
    /// Nudge it clear of the password field. Clamped where it is read.
    static let lockWidgetVerticalOffset = Key<Double>("lockWidgetVerticalOffset", default: 0)
    static let lockFullBackground = Key<LockFullBackground>(
        "lockFullBackground", default: .blurredArtwork)

    //   the ten vinyl* / launcherShowVinylWidget keys
    //                                       retired with VinylWidgetView, which
    //                                       PlayerSurfaceView supersedes. Left in
    //                                       place they would have kept a second,
    //                                       superseded desktop widget switchable.
    //
    // Deliberately absent, and this list is the record of why:
    //
    //   hideNotchOption, perAppVolumeMode   Anchor concepts. VinylPod has no
    //                                       notch and no per-app audio engine.
    //   sneakPeekStyles                     chose between two notch animations;
    //                                       MusicManager now posts
    //                                       .vinylPodTrackDidChange instead.
    //   lockScreenGlassStyle,               come back in Phase 4 with the lock
    //   lockScreenGlassCustomizationMode    screen, together with their enums.
    //
    // A key nothing reads is a dead switch — Anchor shipped four of them and
    // an audit was needed to find them. Add the key with the code that reads it.

}
