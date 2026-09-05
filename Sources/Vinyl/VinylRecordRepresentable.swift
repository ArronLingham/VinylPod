/*
 * Anchor
 * Derived from Atoll (DynamicIsland), itself derived from boring.notch.
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import AppKit
import Defaults
import SwiftUI

// Extracted from VinylWidgetView.swift when PlayerSurfaceView superseded it.
// These two are still live: PlayerSurfaceView draws the record through the
// representable, and VinylProgressStyle backs a Defaults key.

enum VinylProgressStyle: String, Codable, CaseIterable, Defaults.Serializable {
    /// A ring around the record.
    case ring
    /// A line under the transport, with elapsed and remaining times.
    case bar

    var label: String {
        switch self {
        case .ring: return String(localized: "Ring around the record")
        case .bar: return String(localized: "Bar with times")
        }
    }
}

/// Bridges the CALayer record into SwiftUI.
///
/// Only three things cross the boundary — the artwork, whether it is turning,
/// and the label size — so the record never rebuilds its layers for a state
/// change SwiftUI made elsewhere.
struct VinylRecordRepresentable: NSViewRepresentable {
    let artwork: NSImage?
    let isPlaying: Bool
    let labelFraction: CGFloat

    func makeNSView(context: Context) -> VinylRecordView {
        let view = VinylRecordView(frame: .zero)
        view.labelFraction = labelFraction
        view.setArtwork(artwork)
        view.setSpinning(isPlaying)
        return view
    }

    func updateNSView(_ view: VinylRecordView, context: Context) {
        view.labelFraction = labelFraction
        view.setArtwork(artwork)
        view.setSpinning(isPlaying)
    }
}

