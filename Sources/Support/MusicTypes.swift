// Extracted from Anchor/Models/Constants.swift — the music-related enums.
// GPL-3.0. Copyright (C) 2024-2026 Atoll Contributors. See NOTICE.

import AppKit
import Defaults
import Foundation
import SwiftUI

struct CustomVisualizer: Codable, Hashable, Equatable, Defaults.Serializable {
    let UUID: UUID
    var name: String
    var url: URL
    var speed: CGFloat = 1.0
}

enum MediaControllerType: String, CaseIterable, Identifiable, Defaults.Serializable {
    case nowPlaying = "Now Playing"
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case youtubeMusic = "Youtube Music"
    case amazonMusic = "Amazon Music"
    case cider = "Cider"
    
    var id: String { self.rawValue }
    
    var localizedName: String {
        switch self {
        case .nowPlaying: return String(localized: "Now Playing")
        case .appleMusic: return String(localized: "Apple Music")
        case .spotify: return String(localized: "Spotify")
        case .youtubeMusic: return String(localized: "Youtube Music")
        case .amazonMusic: return String(localized: "Amazon Music")
        case .cider: return String(localized: "Cider")
        }
    }
}

enum MusicAuxiliaryControl: String, CaseIterable, Identifiable, Defaults.Serializable {
    case shuffle
    case repeatMode
    case mediaOutput
    case lyrics

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shuffle:
            return "Shuffle"
        case .repeatMode:
            return "Repeat"
        case .mediaOutput:
            return "Media Output"
        case .lyrics:
            return "Lyrics"
        }
    }

    var symbolName: String {
        switch self {
        case .shuffle:
            return "shuffle"
        case .repeatMode:
            return "repeat"
        case .mediaOutput:
            return "laptopcomputer"
        case .lyrics:
            return "quote.bubble"
        }
    }

    static func alternative(
        excluding control: MusicAuxiliaryControl,
        preferring candidate: MusicAuxiliaryControl? = nil
    ) -> MusicAuxiliaryControl {
        if let candidate, candidate != control {
            return candidate
        }

        return allCases.first { $0 != control } ?? .shuffle
    }
}

enum MusicSkipBehavior: String, CaseIterable, Identifiable, Defaults.Serializable {
    case track
    case tenSecond

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .track:
            return String(localized: "Track Skip")
        case .tenSecond:
            return String(localized: "±10 Seconds")
        }
    }

    var description: String {
        switch self {
        case .track:
            return String(localized: "Standard previous/next track controls")
        case .tenSecond:
            return String(localized: "Skip forward or backward by ten seconds")
        }
    }
}

/// How the album-art colour is derived. Ported from Anchor's
/// `Models/Constants.swift` because `RealTimeWaveformScrubberView` reads it.
enum ColorExtractionMode: String, CaseIterable, Identifiable, Defaults.Serializable {
    case legacy, vibrant
    var id: Self { self }
}

/// Ported from Anchor's `Enums/generic.swift` for the same reason.
enum SliderColorEnum: String, CaseIterable, Defaults.Serializable {
    case white = "White"
    case albumArt = "Match album art"
    case accent = "Accent color"

    var localizedName: String {
        switch self {
        case .white: return String(localized: "White")
        case .albumArt: return String(localized: "Match album art")
        case .accent: return String(localized: "Accent color")
        }
    }
}

/// Ported from Anchor's `Enums/generic.swift`. `AnchorAnimations` publishes it;
/// VinylPod has no notch, so `.floating` is the only value that will ever be
/// set here. Kept as-is so the file folds back into Anchor unchanged.
public enum Style {
    case notch
    case floating
}

extension Defaults.Keys {
    /// Apple removed the private MediaRemote API that `NowPlayingController`
    /// uses in macOS 15.4, so newer systems cannot start on `.nowPlaying`.
    ///
    /// Anchor stops there and returns `.appleMusic` unconditionally, which is
    /// wrong on a machine that does not have Music.app: the app starts pointed
    /// at a player that does not exist, shows nothing, and reads as broken with
    /// no error anywhere. So the installed apps are checked, in order of how
    /// likely they are to be the one you meant.
    ///
    /// Ask LaunchServices, never the filesystem. Music.app is at
    /// **`/System/Applications/Music.app`**, not `/Applications` — a check for
    /// the latter reports it missing on a machine that has it, which is how
    /// this function came to be written in the first place. Anchor records the
    /// same trap for Safari, which lives in a cryptex and is invisible to a
    /// directory listing of `/Applications`.
    static var defaultMediaController: MediaControllerType {
        let workspace = NSWorkspace.shared
        func installed(_ bundleID: String) -> Bool {
            workspace.urlForApplication(withBundleIdentifier: bundleID) != nil
        }
        if #available(macOS 15.4, *) {
            if installed("com.apple.Music") { return .appleMusic }
            if installed("com.spotify.client") { return .spotify }
            if installed("com.amazon.music") { return .amazonMusic }
            // Nothing recognised is installed. `.nowPlaying` will not work on
            // this OS either, but it is the one that covers any app the user
            // installs later without them having to find this setting.
            return .nowPlaying
        }
        return .nowPlaying
    }
}

extension Notification.Name {
    /// `AudioRouteManager` posts this when the default output device changes.
    /// Declared in Anchor's `Managers/Audio/SystemMediaControllers.swift`, which
    /// is a HUD and brightness file and was not part of this extraction.
    ///
    /// The string keeps Anchor's prefix on purpose: the two apps run side by
    /// side during development and a distributed observer keyed to it must see
    /// the same name from either.
    static let systemAudioRouteDidChange = Notification.Name("Anchor.systemAudioRouteDidChange")

}
