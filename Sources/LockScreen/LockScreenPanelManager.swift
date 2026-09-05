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
import SkyLightWindow
import SwiftUI

/// Puts the two lock-screen surfaces on screen.
///
/// Both are the same `PlayerSurfaceView` the desktop player uses, against their
/// own layouts — which is the whole point of the engine. Anchor's equivalent is
/// a 1,669-line panel with its own copy of the control renderer.
@MainActor
final class LockScreenPanelManager: ObservableObject {
    static let shared = LockScreenPanelManager()

    /// Whether the small widget has been expanded into the full-screen player.
    @Published private(set) var isImmersive = false

    private var window: LockPanel?
    private weak var delegatedWindow: NSWindow?
    private var isPreviewing = false

    private init() {}

    // MARK: Presentation

    /// Show the lock-screen surfaces without locking the screen.
    ///
    /// Debug only, deliberately. It is a development aid — locking the machine
    /// to check a layout costs a password every time and makes the screen
    /// unreadable to any capture — but it also puts a window at
    /// `CGShieldingWindowLevel` over everything on demand, which is not
    /// something a shipped build should do because an environment variable
    /// said so. Anchor shipped exactly this kind of hook unguarded once and it
    /// leaked a Keychain value into a PNG.
    ///
    ///     VINYLPOD_PREVIEW_LOCK=widget open -n VinylPod.app
    ///     VINYLPOD_PREVIEW_LOCK=full   open -n VinylPod.app
    #if DEBUG
        func previewIfRequested() {
            guard let mode = ProcessInfo.processInfo.environment["VINYLPOD_PREVIEW_LOCK"]
            else { return }
            // Bypass the guard rather than writing the key. A first version set
            // `enableLockScreenWidget = true`, which PERSISTS -- so previewing a
            // layout silently switched on a feature the user had off, and left
            // it on after the preview process died.
            isPreviewing = true
            show()
            if mode == "full" { setImmersive(true) }
        }
    #endif

    func show() {
        guard isPreviewing || Defaults[.enableLockScreenWidget] else { return }
        guard let screen = NSScreen.main else { return }

        isImmersive = false
        let panel = existingOrNewWindow(on: screen)
        panel.setFrame(frame(for: screen, immersive: false), display: true)

        // `CGShieldingWindowLevel()` alone is NOT enough — it puts the window
        // above ordinary windows but still beneath loginwindow's shield, which
        // is what actually covers the screen when locked. Delegating through
        // SkyLight is what gets it in front, and it is a private API.
        //
        // Delegate ONCE. Anchor's note is explicit that repeating it, or
        // closing the window rather than ordering it out, crashes SkyLight.
        // Delegate once per window, and record it against the window rather
        // than as a bare flag — a flag set to true before the call could be
        // wrong about a window that was never actually delegated, and there is
        // no way to notice because the failure is "nothing appears when you
        // lock the screen", hours later.
        if delegatedWindow !== panel {
            SkyLightOperator.shared.delegateWindow(panel)
            delegatedWindow = panel
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        // Ordered out, never closed — see above. The hosting view is released
        // with it: an `NSHostingView` left alive behind an ordered-out window
        // keeps its TimelineViews scheduled and keeps solving the layout, which
        // is the "a loop that no-ops is still a loop" trap in window form.
        window?.orderOut(nil)
        window?.contentView = NSView()
        isImmersive = false
    }

    /// Tapping the artwork on the small widget expands it to the full-screen
    /// player, and vice versa.
    func setImmersive(_ immersive: Bool) {
        guard isImmersive != immersive, let window, let screen = window.screen ?? NSScreen.main
        else { return }
        isImmersive = immersive
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame(for: screen, immersive: immersive), display: true)
        }
    }

    private func existingOrNewWindow(on screen: NSScreen) -> NSPanel {
        if let window {
            // The content view is torn down on hide, so it has to come back.
            if !(window.contentView is NSHostingView<LockScreenRootView>) {
                window.contentView = NSHostingView(rootView: LockScreenRootView(manager: self))
            }
            return window
        }
        // An **NSPanel**, not an NSWindow. `.nonactivatingPanel` is a panel-only
        // style bit: NSWindow accepts it in the mask and ignores it, so the
        // window would try to activate the app on every click and the transport
        // buttons on the lock surface would not reliably get their events.
        //
        // Content is passed through `contentRect` sizing and assigned before the
        // window is ever ordered in, for the reason `PlayerPanel` documents: a
        // borderless window given content later can end up with no backing
        // store and never reach the window server while reporting isVisible.
        let created = LockPanel(
            contentRect: frame(for: screen, immersive: false),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        created.contentView = NSHostingView(rootView: LockScreenRootView(manager: self))
        created.isReleasedWhenClosed = false
        created.isOpaque = false
        created.backgroundColor = .clear
        created.hasShadow = false
        created.isMovable = false
        created.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        created.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        created.onEscape = { [weak self] in self?.setImmersive(false) }
        window = created
        return created
    }

    // MARK: Geometry

    /// The small widget is centred a little above the middle of the screen,
    /// which keeps it clear of the password field.
    private func frame(for screen: NSScreen, immersive: Bool) -> NSRect {
        let full = screen.frame
        guard !immersive else { return full }

        let width = Defaults[.lockWidgetWidth]
        let height = GridSolver.intrinsicHeight(
            layout: Defaults[.playerLayouts].lockWidget, width: width)
        // Clamped, which the key's comment claimed and the code did not do.
        // An unbounded offset puts the panel off the top or bottom of the
        // screen, and there is no way to drag a lock-screen panel back.
        let offset = min(max(Defaults[.lockWidgetVerticalOffset], -240), 240)
        return NSRect(
            x: full.midX - width / 2,
            y: full.midY + full.height * 0.06 - height / 2 + offset,
            width: width, height: height)
    }
}

// MARK: - Root view

private struct LockScreenRootView: View {
    @ObservedObject var manager: LockScreenPanelManager
    @ObservedObject private var music = MusicManager.shared

    @Default(.playerLayouts) private var layouts
    @Default(.lockFullBackground) private var background

    var body: some View {
        if manager.isImmersive {
            immersive
        } else {
            widget
        }
    }

    /// How much of the widget's leading edge is artwork.
    ///
    /// Derived from the layout rather than guessed, so it stays right when the
    /// user moves the artwork or changes its span.
    private var artworkHitWidth: CGFloat {
        let layout = layouts.lockWidget
        guard let art = layout.placements.first(where: { $0.element == .artwork }) else { return 0 }
        let width = Defaults[.lockWidgetWidth]
        let cell = GridSolver.cellWidth(for: layout.geometry, totalWidth: width)
        return layout.geometry.padding
            + GridSolver.resolvedWidth(
                span: art.colSpan, cellWidth: cell, gutter: layout.geometry.gutter)
    }

    // MARK: Small widget

    private var widget: some View {
        PlayerSurfaceView(
            layout: layouts.lockWidget,
            style: .forSurface(.lockWidget, albumColor: music.avgColor, tinted: false,
                               scale: layouts.lockWidget.geometry.contentScale)
        )
        .background(glass)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        // Only the artwork expands, which is what this always claimed and did
        // not do: the gesture was on the whole widget, so double-clicking a
        // transport button threw you into a full-screen overlay.
        .overlay(alignment: .leading) {
            Color.clear
                .frame(width: artworkHitWidth)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { manager.setImmersive(true) }
        }
    }

    /// Liquid glass where the OS has it, a frosted material where it does not.
    ///
    /// The public `glassEffect` is the whole reason the deployment target is
    /// macOS 26; the fallback is kept anyway because it costs one branch and
    /// makes lowering that target later a build-setting change rather than a
    /// rewrite.
    @ViewBuilder private var glass: some View {
        if #available(macOS 26.0, *) {
            Color.clear.glassEffect(
                .regular, in: .rect(cornerRadius: 26))
        } else {
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.ultraThinMaterial)
        }
    }

    // MARK: Full-screen player

    private var immersive: some View {
        ZStack {
            immersiveBackground
            PlayerSurfaceView(
                layout: layouts.lockFull,
                style: .forSurface(.lockFull, albumColor: music.avgColor, tinted: false,
                                   scale: layouts.lockFull.geometry.contentScale))
        }
        .ignoresSafeArea()
        // Deliberately a SINGLE tap, plus Escape (see `LockPanel`), plus the
        // button. This covers the whole display above loginwindow's shield, so
        // needing to discover a double-click to escape it is not acceptable —
        // getting out has to be easier than getting in.
        .onTapGesture { manager.setImmersive(false) }
        .overlay(alignment: .topLeading) {
            Button {
                manager.setImmersive(false)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(10)
                    .background(Circle().fill(.black.opacity(0.35)))
            }
            .buttonStyle(.plain)
            .padding(24)
        }
    }

    /// Two choices, which is what the spec asked for: the album cover itself
    /// blurred, or a flat wash of the colour taken from it.
    @ViewBuilder private var immersiveBackground: some View {
        switch background {
        case .blurredArtwork:
            // Downscale, blur, scale back up. Blurring at full resolution is
            // far more expensive for a result nobody can tell apart, and this
            // is the shape Anchor's immersive player already uses.
            Image(nsImage: music.albumArt)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .blur(radius: 26, opaque: true)
                .scaleEffect(14)
                .saturation(1.7)
                .overlay(Color.black.opacity(0.62))
        case .albumColour:
            Color(nsColor: music.avgColor)
                .overlay(Color.black.opacity(0.45))
        }
    }
}

/// What sits behind the full-screen player.
public enum LockFullBackground: String, Codable, CaseIterable, Defaults.Serializable {
    case blurredArtwork
    case albumColour

    var label: String {
        switch self {
        case .blurredArtwork: return String(localized: "Blurred album cover")
        case .albumColour: return String(localized: "Album cover colour")
        }
    }
}


/// The lock-screen panel.
///
/// Exists for two reasons: `.nonactivatingPanel` is honoured only by `NSPanel`,
/// and a full-screen overlay above the login shield needs a keyboard escape.
final class LockPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { onEscape?() }
}
