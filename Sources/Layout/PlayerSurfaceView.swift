/*
 * VinylPod
 * Copyright (C) 2026 VinylPod Contributors
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
import SwiftUI

/// Draws one surface from its `SurfaceLayout`.
///
/// This is the single renderer. Anchor has the same `switch` copy-pasted into
/// `NotchHomeView`, `MinimalisticMusicPlayerView` and `LockScreenMusicPanel`,
/// and hardcoded outright in `MusicControlOverlay` and `VinylWidgetView` — five
/// places to edit to add one control. Here the *style* is injected and the
/// switch is written once.
struct PlayerSurfaceView: View {
    let layout: SurfaceLayout
    let style: SurfaceStyle
    var hovering: Bool = false

    @ObservedObject private var music = MusicManager.shared

    var body: some View {
        GeometryReader { geo in
            let resolved = GridSolver.solve(
                layout: layout, available: geo.size, hovering: hovering)
            ZStack(alignment: .topLeading) {
                // `elements` arrives base-first then overlay, which is the draw
                // order — the renderer needs no z-index of its own.
                ForEach(resolved.elements, id: \.placement.id) { element in
                    PlayerElementView(
                        placement: element.placement, style: style, music: music
                    )
                    .frame(width: element.frame.width, height: element.frame.height)
                    .offset(x: element.frame.minX, y: element.frame.minY)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }
}

/// Per-surface appearance. The desktop card, the lock-screen glass panel and the
/// launcher card want the same elements at different weights.
struct SurfaceStyle {
    var ink: Color
    var subtleInk: Color
    var accent: Color
    /// Multiplies every font size. The launcher card is small; the lock-screen
    /// full-screen player is not.
    var textScale: CGFloat

    /// `scale` comes from the layout's own `GridGeometry.contentScale`, not
    /// from a table here — the row heights use the same number, and two
    /// separate constants is how a 24pt title ended up in a 20pt row.
    static func forSurface(
        _ surface: PlayerSurface, albumColor: NSColor, tinted: Bool, scale: CGFloat
    ) -> SurfaceStyle {
        let ink: Color =
            tinted
            ? (SurfaceStyle.isLight(SurfaceStyle.muted(albumColor))
                ? .black.opacity(0.82) : .white.opacity(0.92))
            : .white
        return SurfaceStyle(
            ink: ink, subtleInk: ink.opacity(0.55), accent: Color(nsColor: albumColor),
            textScale: scale)
    }

    /// Clamp saturation and brightness so an album's colour is a background
    /// rather than a shout. Lifted from `VinylWidgetView`, which is where the
    /// numbers were arrived at.
    static func muted(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return NSColor(white: 0.16, alpha: 1) }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return NSColor(
            hue: hue, saturation: min(saturation, 0.22),
            brightness: max(0.58, min(brightness, 0.80)), alpha: 1)
    }

    /// Rec. 709 luma — matches how the eye weights the channels, so a saturated
    /// yellow correctly counts as light and a blue does not.
    static func isLight(_ color: NSColor) -> Bool {
        guard let rgb = color.usingColorSpace(.sRGB) else { return false }
        let luma =
            0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
        return luma > 0.45
    }
}

// MARK: - One element

struct PlayerElementView: View {
    let placement: ElementPlacement
    let style: SurfaceStyle
    @ObservedObject var music: MusicManager

    @State private var showingRemaining = false

    var body: some View {
        switch placement.element {
        case .artwork: artwork
        case .title: text(music.songTitle, size: 15, weight: .semibold)
        case .artist: text(music.artistName, size: 12, weight: .regular, subtle: true)
        case .album: text(music.album, size: 12, weight: .regular, subtle: true)

        case .playPause:
            button(music.isPlaying ? "pause.fill" : "play.fill", scale: 1.25) {
                music.playPause()
            }
        case .next: button("forward.end.fill") { music.nextTrack() }
        case .previous: button("backward.end.fill") { music.previousTrack() }
        case .seekForward: button("goforward.10") { music.seek(by: 10) }
        case .seekBackward: button("gobackward.10") { music.seek(by: -10) }
        case .shuffle:
            button("shuffle", active: music.isShuffled) { music.toggleShuffle() }
        case .repeatMode:
            button(music.repeatMode == .one ? "repeat.1" : "repeat",
                   active: music.repeatMode != .off) { music.toggleRepeat() }
        case .lyrics: lyrics

        case .progressBar: progressBar
        case .timeElapsed: timeLabel { Self.timestamp($0) }
        case .timeRemaining:
            timeLabel { "-" + Self.timestamp(max(0, self.music.songDuration - $0)) }
        case .trackTimeToggle: trackTimeToggle

        case .outputDevice: button("speaker.wave.2") {}
        case .airPlay: button("airplayaudio") {}
        case .volumeSlider: placeholder("speaker.wave.2")
        case .visualizer: visualizer

        case .appIcon: appIcon
        case .explicitBadge: explicitBadge
        case .clock: clock
        case .timer: placeholder("timer")
        }
    }

    /// `lyrics` is two things, and which one you get follows the room it was
    /// given — which is what a grid is for. One cell is a toggle button, as it
    /// is in a transport row. Three or more is the scrolling panel, as it is on
    /// the full-screen lock player, where the layout hands it half the screen.
    ///
    /// Before this, a span-6 placement rendered a 13pt speech-bubble glyph in
    /// the middle of an empty half-screen.
    @ViewBuilder private var lyrics: some View {
        if placement.colSpan >= 3 {
            if music.syncedLyrics.isEmpty {
                Text(music.currentLyrics.isEmpty ? "" : music.currentLyrics)
                    .font(.system(size: 15 * style.textScale, weight: .medium))
                    .foregroundStyle(style.subtleInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SyncedLyricsList(
                    currentSize: 15 * style.textScale, otherSize: 12 * style.textScale,
                    lineSpacing: 10 * style.textScale, fitted: true, fittedCapacity: 5,
                    linesBefore: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            button("quote.bubble", active: music.showLyrics) { music.toggleLyrics() }
        }
    }

    // MARK: Artwork

    @ViewBuilder private var artwork: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                switch placement.artworkStyle.kind {
                case .vinyl:
                    // labelFraction 0.46 matches what VinylWidgetView passes;
                    // the view's own default of 0.38 is for a smaller record.
                    VinylRecordRepresentable(
                        artwork: music.albumArt,
                        isPlaying: music.isPlaying,
                        labelFraction: 0.46)
                    if placement.artworkStyle.showsStylus {
                        tonearm(side: side)
                    }
                case .cover:
                    Image(nsImage: music.albumArt)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: side * 0.06, style: .continuous))
                }
                if placement.artworkStyle.showsProgressRing {
                    progressRing(side: side)
                }
            }
            .frame(width: side, height: side)
            .frame(width: geo.size.width, height: geo.size.height)
            // The record is itself the largest play/pause target, which is how
            // the vinyl widget already behaves.
            .contentShape(placement.artworkStyle.kind == .vinyl ? AnyShape(Circle()) : AnyShape(Rectangle()))
            .onTapGesture { music.playPause() }
        }
    }

    private func progressRing(side: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: music.isPlaying ? 0.25 : 60)) { context in
            Circle()
                .trim(from: 0, to: fraction(at: context.date))
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .foregroundStyle(style.ink.opacity(0.85))
                .rotationEffect(.degrees(-90))
                .frame(width: side * 1.045, height: side * 1.045)
        }
    }

    // MARK: Text

    private func text(_ value: String, size: CGFloat, weight: Font.Weight, subtle: Bool = false)
        -> some View
    {
        Text(value)
            .font(.system(size: size * style.textScale, weight: weight))
            .foregroundStyle(subtle ? style.subtleInk : style.ink)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Buttons

    private func button(
        _ symbol: String, scale: CGFloat = 1, active: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13 * scale * style.textScale, weight: .medium))
                .foregroundStyle(active ? style.accent : style.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func placeholder(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12 * style.textScale))
            .foregroundStyle(style.subtleInk)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Progress and time

    /// Interpolated locally rather than driven by a publish per frame.
    ///
    /// `MusicManager` is event-driven: `elapsedTime` is assigned when the
    /// controller reports a time change, not on a tick. `estimatedPlaybackPosition`
    /// projects forward from that using `timestampDate` and `playbackRate`, so a
    /// `TimelineView` can animate smoothly while the manager stays quiet. This
    /// is the pattern that keeps the notch player cheap in Anchor, and it is the
    /// reason a 27-property `@Published` object does not re-render the world.
    private func fraction(at date: Date) -> CGFloat {
        guard music.songDuration > 0, music.songDuration.isFinite else { return 0 }
        let position = music.estimatedPlaybackPosition(at: date)
        return min(max(position / music.songDuration, 0), 1)
    }

    private var progressBar: some View {
        TimelineView(.periodic(from: .now, by: music.isPlaying ? 0.25 : 60)) { context in
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(style.ink.opacity(0.22))
                    Capsule().fill(style.ink.opacity(0.85))
                        .frame(width: geo.size.width * fraction(at: context.date))
                }
                .frame(height: 3)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { point in
                    guard music.songDuration > 0, music.songDuration.isFinite else { return }
                    music.seek(to: music.songDuration * (point.x / max(1, geo.size.width)))
                }
            }
        }
    }

    private func timeLabel(_ format: @escaping (TimeInterval) -> String) -> some View {
        TimelineView(.periodic(from: .now, by: music.isPlaying ? 0.5 : 60)) { context in
            Text(format(music.estimatedPlaybackPosition(at: context.date)))
                .font(.system(size: 10 * style.textScale, weight: .medium).monospacedDigit())
                .foregroundStyle(style.subtleInk)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var trackTimeToggle: some View {
        Button {
            showingRemaining.toggle()
        } label: {
            TimelineView(.periodic(from: .now, by: music.isPlaying ? 0.5 : 60)) { context in
                let position = music.estimatedPlaybackPosition(at: context.date)
                Text(
                    showingRemaining
                        ? "-" + Self.timestamp(max(0, music.songDuration - position))
                        : Self.timestamp(position)
                )
                .font(.system(size: 10 * style.textScale, weight: .medium).monospacedDigit())
                .foregroundStyle(style.subtleInk)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }

    /// A live stream reports a NaN duration as a matter of course, and
    /// `Int(someDouble)` **traps** on NaN — not an exception, a hard crash.
    /// Anchor took a SIGTRAP here while simply drawing elapsed time over live
    /// content, in two separate files with the same helper.
    static func timestamp(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: Extras

    private var visualizer: some View {
        // `AudioVisualizerView` takes a Binding because Anchor's callers own the
        // state. Nothing here writes it back, so a constant is honest — and it
        // matters that this view is only constructed when the element is placed:
        // the real-time variant acquires the CoreAudio process tap, which is
        // reference-counted and must not be held by a surface nobody is looking
        // at. That single mistake was worth 12x Anchor's idle CPU.
        AudioVisualizerView(isPlaying: .constant(music.isPlaying))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The tonearm, ported from `VinylWidgetView`. It lives here rather than in
    /// `VinylRecordView` because that view is CALayer-based and deliberately
    /// rotates everything it owns — an arm inside it would spin with the record.
    private func tonearm(side: CGFloat) -> some View {
        let pivot = side * 0.16
        let armLength = side * 0.50
        return ZStack(alignment: .top) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.95), Color(white: 0.62)],
                        center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: pivot * 0.7))
                .frame(width: pivot, height: pivot)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(white: 0.28))
                    .frame(width: max(2.5, side * 0.019), height: armLength)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(white: 0.22))
                    .frame(width: side * 0.07, height: side * 0.072)
            }
            .offset(y: pivot * 0.45)
            .rotationEffect(.degrees(music.isPlaying ? 32 : 12), anchor: .top)
            .animation(.spring(response: 0.75, dampingFraction: 0.82), value: music.isPlaying)
        }
        .frame(width: pivot, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(false)
    }

    @ViewBuilder private var appIcon: some View {
        if let bundleID = music.bundleIdentifier, let icon = AppIconAsNSImage(for: bundleID) {
            Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }

    @ViewBuilder private var explicitBadge: some View {
        if music.isCurrentTrackExplicit {
            Image(systemName: "e.square.fill")
                .font(.system(size: 10 * style.textScale))
                .foregroundStyle(style.subtleInk)
        } else {
            Color.clear
        }
    }

    /// The system schedules this; nothing here polls. A minute-granularity
    /// `TimelineView` wakes once a minute and not otherwise.
    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(context.date, style: .time)
                .font(.system(size: 13 * style.textScale, weight: .medium).monospacedDigit())
                .foregroundStyle(style.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Type-erased shape so `contentShape` can pick between a circle and a rect.
private struct AnyShape: Shape {
    private let make: (CGRect) -> Path
    init<S: Shape>(_ shape: S) { make = { shape.path(in: $0) } }
    func path(in rect: CGRect) -> Path { make(rect) }
}
