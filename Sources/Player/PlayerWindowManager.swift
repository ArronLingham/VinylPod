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
import Combine
import Defaults
import SwiftUI

/// Owns the desktop player's window.
///
/// Derived from Anchor's `VinylWidgetWindowManager` — the panel setup, the frame
/// autosave, the on-screen clamp and the display-sleep teardown all come from
/// there and were all worth keeping. What is new is everything to do with the
/// pointer: mouse resize, hover growth, and double-click to send to the back.
@MainActor
final class PlayerWindowManager: ObservableObject {
    static let shared = PlayerWindowManager()

    /// Width is the one thing the user sets directly. Height follows from what
    /// the layout needs, so there is never an empty strip at the bottom.
    @Published private(set) var width: CGFloat = Defaults[.playerWidth]
    @Published private(set) var isHovering = false

    private var panel: PlayerPanel?
    private var cancellables = Set<AnyCancellable>()
    private var hoverModel = PlayerHoverModel()

    private init() {}

    func start() {
        Defaults.publisher(.enablePlayerWidget, options: [])
            .sink { [weak self] _ in Task { @MainActor in self?.sync() } }
            .store(in: &cancellables)
        Defaults.publisher(.playerWindowLevel, options: [])
            .sink { [weak self] _ in Task { @MainActor in self?.applyLevel() } }
            .store(in: &cancellables)
        Defaults.publisher(.playerLayouts, options: [])
            .sink { [weak self] _ in Task { @MainActor in self?.relayout(animated: true) } }
            .store(in: &cancellables)

        // The widget is torn down entirely while the display sleeps rather than
        // left running behind a black screen. Same reason the record's
        // CABasicAnimation is removed on pause rather than set to zero speed.
        SystemActivityGate.shared.$shouldSuspendBackgroundWork
            .receive(on: DispatchQueue.main)
            .sink { [weak self] suspended in
                MainActor.assumeIsolated { suspended == true ? self?.tearDown() : self?.sync() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.clampOnScreen() }
        }

        sync()
    }

    // MARK: Lifecycle

    func sync() {
        guard Defaults[.enablePlayerWidget], !SystemActivityGate.shared.shouldSuspendBackgroundWork
        else {
            tearDown()
            return
        }
        if panel == nil { build() }
        relayout(animated: false)
        applyLevel()
        panel?.orderFrontRegardless()
    }

    private func build() {
        let host = NSHostingView(rootView: PlayerRootView(manager: self))
        host.translatesAutoresizingMaskIntoConstraints = true
        let size = NSSize(width: width, height: targetHeight(hovering: false))
        let created = PlayerPanel(contentView: host, size: size)

        created.onResize = { [weak self] proposed in
            MainActor.assumeIsolated { self?.applyUserSize(proposed) }
        }
        created.onHoverChange = { [weak self] hovering in
            MainActor.assumeIsolated { self?.setHovering(hovering) }
        }
        created.onSendToBack = {
            MainActor.assumeIsolated { Defaults[.playerWindowLevel] = .desktop }
        }
        created.isDeadSpace = { [weak self] point in
            MainActor.assumeIsolated { self?.isDeadSpace(at: point) ?? true }
        }

        created.setFrameAutosaveName("VinylPodPlayer")
        if created.frame.origin == .zero { created.setFrameOrigin(defaultOrigin(for: size)) }
        panel = created
        clampOnScreen()
    }

    private func tearDown() {
        guard let panel else { return }
        panel.saveFrame(usingName: "VinylPodPlayer")
        panel.orderOut(nil)
        self.panel = nil
    }

    func persistFrame() { panel?.saveFrame(usingName: "VinylPodPlayer") }

    // MARK: Size

    private var layout: SurfaceLayout { Defaults[.playerLayouts].desktop }

    /// The height the window should be.
    ///
    /// When the user has dragged the bottom edge, that is a *budget* and the
    /// solver drops elements to fit it. Otherwise it is whatever the layout
    /// needs, so there is never an empty strip at the bottom — the mistake
    /// `VinylWidgetSize.height` was written to correct.
    private func targetHeight(hovering: Bool) -> CGFloat {
        let intrinsic = GridSolver.intrinsicHeight(
            layout: layout, width: width, hovering: hovering)
        let budget = Defaults[.playerHeightBudget]
        guard budget > 0 else { return intrinsic }
        return min(intrinsic, budget)
    }

    private func applyUserSize(_ proposed: CGSize) {
        width = proposed.width
        Defaults[.playerWidth] = proposed.width
        // -1 means "this drag was horizontal only" — leave the budget alone
        // rather than pinning it to whatever the height happened to be, which
        // would silently freeze the layout after any sideways resize.
        if proposed.height >= 0 { Defaults[.playerHeightBudget] = proposed.height }
        relayout(animated: false)
    }

    /// Resize during a drag is not animated — an animation lagging behind the
    /// pointer feels like the window resisting.
    private func relayout(animated: Bool) {
        guard let panel else { return }
        let target = NSRect(
            x: panel.frame.minX,
            y: panel.frame.maxY - targetHeight(hovering: isHovering),
            width: width,
            height: targetHeight(hovering: isHovering))
        // Anchored at the TOP edge: a widget that grows downward stays put where
        // the user left it, whereas growing from the bottom-left origin makes
        // the whole card jump up the screen on hover.
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                // 0.24s in, matching the timings Anchor's music control window
                // arrived at.
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true)
        }
        clampOnScreen()
    }

    // MARK: Hover

    private func setHovering(_ hovering: Bool) {
        guard isHovering != hovering else { return }
        isHovering = hovering
        guard Defaults[.hoverGrowsWidget], !(panel?.isResizing ?? false) else { return }

        // Only move the window if the hover set genuinely needs more room. A
        // hover-only button placed as an overlay adds no row, so nothing here
        // fires — which is the requirement, and the reason growth is derived
        // rather than configured.
        let metrics = GridSolver.hoverMetrics(layout: layout, width: width)
        guard metrics.grows else { return }
        relayout(animated: true)
    }

    /// Whether a point is somewhere a double-click should send the widget back.
    ///
    /// Asks the solver rather than guessing: anything whose `ElementMetrics`
    /// says it is interactive is not dead space.
    private func isDeadSpace(at point: CGPoint) -> Bool {
        guard let panel else { return true }
        let resolved = GridSolver.solve(
            layout: layout,
            available: CGSize(width: panel.frame.width, height: panel.frame.height),
            hovering: isHovering)
        return !resolved.elements.contains {
            $0.placement.element.metrics.isInteractive && $0.frame.contains(point)
        }
    }

    // MARK: Placement

    private func applyLevel() { panel?.level = Defaults[.playerWindowLevel].windowLevel }

    private func defaultOrigin(for size: NSSize) -> NSPoint {
        guard let visible = NSScreen.main?.visibleFrame else { return .zero }
        return NSPoint(x: visible.maxX - size.width - 40, y: visible.minY + 40)
    }

    /// Resizing keeps the origin, so shrinking or growing near a screen edge can
    /// walk a borderless panel off the display — and one you cannot see is one
    /// you cannot drag back. Anchor hit this going from Small (190pt) to Desktop
    /// (560pt) in the corner.
    private func clampOnScreen() {
        guard let panel,
            let visible = (panel.screen ?? NSScreen.main)?.visibleFrame
        else { return }
        var frame = panel.frame
        frame.origin.x = min(frame.origin.x, visible.maxX - frame.width)
        frame.origin.y = min(frame.origin.y, visible.maxY - frame.height)
        frame.origin.x = max(frame.origin.x, visible.minX)
        frame.origin.y = max(frame.origin.y, visible.minY)
        if frame != panel.frame { panel.setFrame(frame, display: true) }
    }
}

/// Placeholder for hover state that will grow when the settings editor lands.
private struct PlayerHoverModel {}

// MARK: - Root view

private struct PlayerRootView: View {
    @ObservedObject var manager: PlayerWindowManager
    @ObservedObject private var music = MusicManager.shared

    @Default(.playerLayouts) private var layouts
    @Default(.playerTintsWithAlbum) private var tinted
    @Default(.playerBackgroundOpacity) private var backgroundOpacity

    @State private var showingCloseChoice = false

    var body: some View {
        PlayerSurfaceView(
            layout: layouts.desktop,
            style: .forSurface(.desktop, albumColor: music.avgColor, tinted: tinted,
                               scale: layouts.desktop.geometry.contentScale),
            hovering: manager.isHovering
        )
        .background(card)
        .overlay(alignment: .topTrailing) { closeButton }
        .contextMenu { menu }
        .animation(.easeInOut(duration: 0.35), value: music.avgColor)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(cardColor.opacity(backgroundOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var cardColor: Color {
        tinted ? Color(nsColor: SurfaceStyle.muted(music.avgColor)) : Color(white: 0.12)
    }

    /// Closing offers a choice rather than doing something silently. Anchor's
    /// close button set the window level to desktop with no indication that is
    /// what it had done, so it read as a broken quit.
    @ViewBuilder private var closeButton: some View {
        if manager.isHovering {
            Button {
                showingCloseChoice = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(5)
                    .background(Circle().fill(.black.opacity(0.35)))
            }
            .buttonStyle(.plain)
            .padding(8)
            .popover(isPresented: $showingCloseChoice, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Close the player").font(.headline)
                    Button("Send to the back") {
                        Defaults[.playerWindowLevel] = .desktop
                        showingCloseChoice = false
                    }
                    Text("Stays on the desktop, behind your windows.")
                        .font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Button("Quit VinylPod") { NSApp.terminate(nil) }
                    Text("Turn the widget off in Settings to hide it without quitting.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(width: 250)
            }
        }
    }

    @ViewBuilder private var menu: some View {
        Picker("Position", selection: Binding(
            get: { Defaults[.playerWindowLevel] },
            set: { Defaults[.playerWindowLevel] = $0 })
        ) {
            ForEach(PlayerWindowLevel.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        Toggle("Tint with the album colour", isOn: Binding(
            get: { Defaults[.playerTintsWithAlbum] },
            set: { Defaults[.playerTintsWithAlbum] = $0 }))
        Toggle("Grow on hover", isOn: Binding(
            get: { Defaults[.hoverGrowsWidget] },
            set: { Defaults[.hoverGrowsWidget] = $0 }))
        Divider()
        Button("Player settings…") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
