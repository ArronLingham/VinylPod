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
import Defaults
import SwiftUI

/// Arrange a surface by dragging its elements around.
///
/// The preview is the **real** `PlayerSurfaceView` — real glass, real album
/// tint, a really spinning record — with a grid and a drag layer over the top.
/// Anchor's `MusicSlotConfigurationView` draws grey rounded rects instead,
/// which cannot show you any of that, so you arrange blind and check on the
/// real thing.
///
/// It is bound to `PlayerSnapshot.sample` rather than to what is playing: a
/// layout that shifts under the cursor when a track changes is miserable to
/// work with, and the sample's deliberately long title shows you truncation
/// without waiting for a song that has one.
struct LayoutEditorView: View {
    @Default(.playerLayouts) private var layouts
    @State private var surface: PlayerSurface = .desktop
    @State private var selection: UUID?
    @State private var dragging: UUID?
    @State private var hoverPreview = false

    private var layout: SurfaceLayout {
        get { layouts[surface] }
        nonmutating set { layouts[surface] = newValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            surfacePicker
            Divider()
            HSplitView {
                VStack(spacing: 10) {
                    preview
                    palette
                }
                .padding(14)
                .frame(minWidth: 420)

                inspector
                    .frame(width: 260)
            }
        }
        .frame(minWidth: 720, minHeight: 560)
    }

    // MARK: Surface picker

    private var surfacePicker: some View {
        HStack {
            Picker("", selection: $surface) {
                ForEach(PlayerSurface.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: surface) { _, _ in selection = nil }

            Spacer()

            Toggle("Show hover elements", isOn: $hoverPreview)
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Preview what appears when the pointer is over this surface.")
        }
        .padding(12)
    }

    // MARK: Preview

    /// A representative size per surface, so the preview is proportioned like
    /// the real thing rather than like the settings window.
    private var previewSize: CGSize {
        switch surface {
        case .desktop: return CGSize(width: 320, height: 0)
        case .lockWidget: return CGSize(width: 380, height: 0)
        case .lockFull: return CGSize(width: 640, height: 400)
        case .launcher: return CGSize(width: 220, height: 0)
        }
    }

    private var resolvedPreview: GridSolver.ResolvedLayout {
        let size = previewSize
        let height =
            size.height > 0
            ? size.height
            : GridSolver.intrinsicHeight(
                layout: layout, width: size.width, hovering: hoverPreview)
        return GridSolver.solve(
            layout: layout, available: CGSize(width: size.width, height: height),
            hovering: hoverPreview)
    }

    private var preview: some View {
        let size = previewSize
        let height =
            size.height > 0
            ? size.height
            : GridSolver.intrinsicHeight(
                layout: layout, width: size.width, hovering: hoverPreview)
        let resolved = resolvedPreview

        return ZStack(alignment: .topLeading) {
            backdrop
            PlayerSurfaceView(
                layout: layout,
                style: .forSurface(
                    surface, albumColor: PlayerSnapshot.sample.avgColor,
                    tinted: surface == .desktop, scale: layout.geometry.contentScale),
                hovering: hoverPreview,
                snapshot: .sample
            )
            .allowsHitTesting(false)

            gridOverlay(width: size.width, height: height, resolved: resolved)
            dragLayer(resolved: resolved, width: size.width, height: height)
        }
        .frame(width: size.width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: hoverPreview)
    }

    @ViewBuilder private var backdrop: some View {
        switch surface {
        case .desktop:
            Color(nsColor: SurfaceStyle.muted(PlayerSnapshot.sample.avgColor))
        case .lockWidget, .lockFull:
            LinearGradient(
                colors: [Color(white: 0.16), Color(white: 0.08)],
                startPoint: .top, endPoint: .bottom)
        case .launcher:
            Color(white: 0.14)
        }
    }

    /// The cells, drawn only while something is being dragged. A permanent grid
    /// over a live preview makes it impossible to judge the layout.
    @ViewBuilder private func gridOverlay(
        width: CGFloat, height: CGFloat, resolved: GridSolver.ResolvedLayout
    ) -> some View {
        if dragging != nil {
            let geometry = layout.geometry
            let cell = GridSolver.cellWidth(for: geometry, totalWidth: width)
            Canvas { context, _ in
                var y = geometry.padding
                for rowHeight in resolved.rowHeights + [24] {
                    for column in 0..<geometry.columns {
                        let x = geometry.padding + CGFloat(column) * (cell + geometry.gutter)
                        context.stroke(
                            Path(
                                roundedRect: CGRect(x: x, y: y, width: cell, height: rowHeight),
                                cornerRadius: 3),
                            with: .color(.white.opacity(0.22)), lineWidth: 1)
                    }
                    y += rowHeight + geometry.gutter
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// One transparent handle per placement, sitting exactly where the renderer
    /// drew it.
    ///
    /// The handles come from the same `ResolvedLayout` the surface was drawn
    /// from, so what you grab is always what you see — hit-testing against a
    /// second, independently computed layout is how a drag ends up one row off.
    private func dragLayer(
        resolved: GridSolver.ResolvedLayout, width: CGFloat, height: CGFloat
    ) -> some View {
        ForEach(resolved.elements, id: \.placement.id) { element in
            let isSelected = selection == element.placement.id
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.accentColor.opacity(isSelected ? 0.28 : 0.001))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(
                            Color.accentColor.opacity(isSelected ? 0.9 : 0),
                            lineWidth: 1.5)
                )
                .frame(width: element.frame.width, height: element.frame.height)
                .offset(x: element.frame.minX, y: element.frame.minY)
                .onTapGesture { selection = element.placement.id }
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .local)
                        .onChanged { _ in
                            selection = element.placement.id
                            dragging = element.placement.id
                        }
                        .onEnded { value in
                            move(
                                element.placement.id, to: value.location,
                                resolved: resolved, width: width)
                            dragging = nil
                        }
                )
        }
    }

    /// Drop a placement wherever the pointer ended up.
    ///
    /// A move that lands on an occupied cell is **refused**, not squeezed in —
    /// the grid's one invariant is that two base placements never share a cell,
    /// and honouring it here means the user gets a no-op rather than a layout
    /// the solver will silently repair behind them.
    private func move(
        _ id: UUID, to point: CGPoint, resolved: GridSolver.ResolvedLayout, width: CGFloat
    ) {
        guard
            let cell = GridSolver.cell(
                at: point, geometry: layout.geometry, totalWidth: width,
                rowHeights: resolved.rowHeights),
            let index = layout.placements.firstIndex(where: { $0.id == id })
        else { return }

        var moved = layout.placements[index]
        moved.col = min(cell.col, layout.geometry.columns - moved.colSpan)
        moved.row = cell.row
        guard GridSolver.canPlace(moved, in: layout, ignoring: id) else { return }

        var updated = layout
        updated.placements[index] = moved
        layout = normalisingRows(updated)
    }

    /// Rows must stay contiguous from zero. Dropping onto "one past the last
    /// row" is how you make a new bottom row, and without this that leaves a
    /// gap the solver compacts away — so the saved layout and the drawn one
    /// disagree, and the next drag computes against the wrong rows.
    private func normalisingRows(_ input: SurfaceLayout) -> SurfaceLayout {
        var output = input
        let rows = Set(output.placements.map(\.row)).sorted()
        var map: [Int: Int] = [:]
        for (index, row) in rows.enumerated() { map[row] = index }
        for index in output.placements.indices {
            output.placements[index].row = map[output.placements[index].row] ?? 0
        }
        return output
    }

    // MARK: Palette

    private var palette: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add an element").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(PlayerElement.allCases, id: \.self) { element in
                        Button {
                            add(element)
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: element.paletteSymbol)
                                    .font(.system(size: 13))
                                Text(element.paletteLabel)
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                            }
                            .frame(width: 64, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.primary.opacity(0.07)))
                        }
                        .buttonStyle(.plain)
                        .help("Add \(element.paletteLabel) to this surface")
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 52)
        }
    }

    /// Place a new element in the first free cell, or on a new bottom row if
    /// there is none.
    private func add(_ element: PlayerElement) {
        var updated = layout
        let span = min(element.metrics.preferredSpan, updated.geometry.columns)
        let rows = (Set(updated.placements.map(\.row)).max() ?? -1) + 1

        var placed: ElementPlacement?
        outer: for row in 0...max(0, rows) {
            for column in 0...(updated.geometry.columns - span) {
                let candidate = ElementPlacement(
                    element: element, col: column, row: row, colSpan: span,
                    priority: element.defaultPriority)
                if GridSolver.canPlace(candidate, in: updated) {
                    placed = candidate
                    break outer
                }
            }
        }
        guard let placement = placed ?? nil else { return }
        updated.placements.append(placement)
        layout = normalisingRows(updated)
        selection = placement.id
    }

    // MARK: Inspector

    @ViewBuilder private var inspector: some View {
        if let id = selection,
            let index = layout.placements.firstIndex(where: { $0.id == id })
        {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(layout.placements[index].element.paletteLabel)
                        .font(.headline)

                    Picker("Shown", selection: binding(index, \.visibility)) {
                        Text("Always").tag(ElementVisibility.always)
                        Text("On hover").tag(ElementVisibility.onHover)
                    }

                    Picker("Layer", selection: binding(index, \.layer)) {
                        Text("In the grid").tag(ElementLayer.base)
                        Text("On top").tag(ElementLayer.overlay)
                    }
                    Text(
                        layout.placements[index].layer == .overlay
                            ? "Draws over whatever is beneath it and adds no height, so revealing it on hover will not make the surface grow."
                            : "Takes its own space. Revealing this on hover makes the surface taller."
                    )
                    .font(.caption).foregroundStyle(.secondary)

                    // The range is computed first because a `...` split across
                    // lines does not parse inside an argument list.
                    let minimum = layout.placements[index].element.metrics.minSpan
                    let maximum = max(
                        minimum, layout.geometry.columns - layout.placements[index].col)
                    Stepper(
                        "Width: \(layout.placements[index].colSpan) of \(layout.geometry.columns)",
                        value: binding(index, \.colSpan), in: minimum...maximum)

                    VStack(alignment: .leading, spacing: 3) {
                        Stepper(
                            "Priority: \(layout.placements[index].priority)",
                            value: binding(index, \.priority), in: 0...9)
                        Text(
                            layout.placements[index].priority == 0
                                ? "Never removed, however small the surface gets."
                                : "Higher numbers are removed first as the surface shrinks."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }

                    if layout.placements[index].element == .artwork {
                        Divider()
                        Picker("Style", selection: binding(index, \.artworkStyle.kind)) {
                            Text("Album cover").tag(ArtworkStyle.Kind.cover)
                            Text("Vinyl record").tag(ArtworkStyle.Kind.vinyl)
                        }
                        if layout.placements[index].artworkStyle.kind == .vinyl {
                            Toggle("Tonearm", isOn: binding(index, \.artworkStyle.showsStylus))
                            Toggle(
                                "Progress ring around the record",
                                isOn: binding(index, \.artworkStyle.showsProgressRing))
                        }
                    }

                    Divider()
                    Button(role: .destructive) {
                        var updated = layout
                        updated.placements.removeAll { $0.id == id }
                        layout = normalisingRows(updated)
                        selection = nil
                    } label: {
                        Label("Remove from this surface", systemImage: "trash")
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 26)).foregroundStyle(.tertiary)
                Text("Select an element in the preview")
                    .font(.callout).foregroundStyle(.secondary)
                Text("Drag it to move it. Add more from the row below.")
                    .font(.caption).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                Divider().padding(.vertical, 6)
                Button("Reset this surface") {
                    layout = PlayerLayouts.defaults[surface]
                    selection = nil
                }
            }
            .padding(20)
            .frame(maxHeight: .infinity)
        }
    }

    private func binding<Value>(
        _ index: Int, _ path: WritableKeyPath<ElementPlacement, Value>
    ) -> Binding<Value> {
        Binding(
            get: { layouts[surface].placements[index][keyPath: path] },
            set: { layouts[surface].placements[index][keyPath: path] = $0 })
    }
}

// MARK: - Palette metadata

extension PlayerElement {
    var paletteLabel: String {
        switch self {
        case .artwork: return "Artwork"
        case .title: return "Title"
        case .artist: return "Artist"
        case .album: return "Album"
        case .playPause: return "Play"
        case .next: return "Next"
        case .previous: return "Previous"
        case .seekBackward: return "Back 10s"
        case .seekForward: return "Skip 10s"
        case .shuffle: return "Shuffle"
        case .repeatMode: return "Repeat"
        case .progressBar: return "Progress"
        case .timeElapsed: return "Elapsed"
        case .timeRemaining: return "Remaining"
        case .trackTimeToggle: return "Time"
        case .lyrics: return "Lyrics"
        case .outputDevice: return "Output"
        case .airPlay: return "AirPlay"
        case .volumeSlider: return "Volume"
        case .visualizer: return "Visualiser"
        case .appIcon: return "App icon"
        case .explicitBadge: return "Explicit"
        case .clock: return "Clock"
        case .timer: return "Timer"
        }
    }

    var paletteSymbol: String {
        switch self {
        case .artwork: return "opticaldisc"
        case .title: return "textformat"
        case .artist: return "person"
        case .album: return "square.stack"
        case .playPause: return "play.fill"
        case .next: return "forward.end.fill"
        case .previous: return "backward.end.fill"
        case .seekBackward: return "gobackward.10"
        case .seekForward: return "goforward.10"
        case .shuffle: return "shuffle"
        case .repeatMode: return "repeat"
        case .progressBar: return "slider.horizontal.below.rectangle"
        case .timeElapsed: return "clock.arrow.circlepath"
        case .timeRemaining: return "clock.badge.checkmark"
        case .trackTimeToggle: return "clock.arrow.2.circlepath"
        case .lyrics: return "quote.bubble"
        case .outputDevice: return "hifispeaker"
        case .airPlay: return "airplayaudio"
        case .volumeSlider: return "speaker.wave.2"
        case .visualizer: return "waveform"
        case .appIcon: return "app"
        case .explicitBadge: return "e.square"
        case .clock: return "clock"
        case .timer: return "timer"
        }
    }

    /// Where a newly added element sits in the drop order.
    ///
    /// Nothing added from the palette is priority 0: an element the user just
    /// placed should not outrank the artwork and play button that were there
    /// first, and they can promote it in the inspector.
    var defaultPriority: Int {
        switch self {
        case .artwork, .playPause: return 1
        case .title, .progressBar: return 3
        case .artist, .next, .previous: return 4
        default: return 6
        }
    }
}
