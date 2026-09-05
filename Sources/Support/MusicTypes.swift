// Extracted from Anchor/Models/Constants.swift — the music-related enums.
// GPL-3.0. Copyright (C) 2024-2026 Atoll Contributors. See NOTICE.

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
