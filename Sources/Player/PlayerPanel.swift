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

/// Where the desktop player sits in the window stack.
public enum PlayerWindowLevel: String, Codable, CaseIterable, Defaults.Serializable {
    /// Pinned to the desktop, behind everything. This is "sent to the back".
    case desktop
    /// An ordinary window.
    case normal
    /// Above ordinary windows.
    case floating

    var windowLevel: NSWindow.Level {
        switch self {
        case .desktop: return NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        case .normal: return .normal
        case .floating: return .floating
        }
    }

    var label: String {
        switch self {
        case .desktop: return String(localized: "On the desktop")
        case .normal: return String(localized: "With other windows")
        case .floating: return String(localized: "Above other windows")
        }
    }
}

// MARK: - The panel

/// Borderless, non-activating, and user-resizable from its edges.
///
/// Nothing in Anchor resizes a borderless panel — every one of its dozen panels
/// is fixed-size or preset-sized, `.resizable` appears only on two ordinary
/// titled windows, and there is no `mouseDragged` resize path anywhere. So the
/// edge tracking and the drag maths below are new, and the parts most likely to
/// be wrong are called out where they are.
final class PlayerPanel: NSPanel {
    /// How close to an edge counts as grabbing it.
    private static let resizeMargin: CGFloat = 6
    /// Never let the user shrink it into a dot they cannot find again.
    private static let minimumWidth: CGFloat = 140
    private static let minimumHeight: CGFloat = 80

    /// Set while a resize drag is in progress, so hover growth stays out of the
    /// way. Growing the window under a pointer that is actively dragging its
    /// edge fights the user for control of the frame.
    private(set) var isResizing = false

    var onResize: ((CGSize) -> Void)?
    var onHoverChange: ((Bool) -> Void)?
    var onSendToBack: (() -> Void)?
    /// Asked whether the point (in view coordinates, top-left origin) is dead
    /// space. Only dead space responds to a double-click.
    var isDeadSpace: ((CGPoint) -> Bool)?

    private var resizeOrigin: NSPoint?
    private var resizeStartFrame: NSRect?
    private var resizeEdge: Edge?
    private var trackingArea: NSTrackingArea?

    private enum Edge {
        case left, right, bottom, bottomLeft, bottomRight
    }

    init(contentView: NSView, size: NSSize) {
        // The content view is passed to `init` rather than assigned afterwards.
        // A borderless panel given its content later can end up with no backing
        // store and never reach the window server, while still reporting
        // `isVisible == true` — which looks exactly like a layout bug and is not.
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        self.contentView = contentView

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isFloatingPanel = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        acceptsMouseMovedEvents = true
        installTrackingArea()
    }

    /// Taking key focus would deactivate whatever app the user is in, and macOS
    /// would hand focus back to *that* app on dismissal — fighting the thing a
    /// desktop widget is for.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: Tracking

    /// Installed ONCE, at init, and never rebuilt.
    ///
    /// It used to be rebuilt from `setFrame`, which crashed the app with
    /// EXC_BAD_ACCESS inside `objc_retain` the first time the pointer entered
    /// the window. The stack said why: `mouseEntered` -> `setHovering` ->
    /// `relayout` -> `setFrame` -> rebuild. Removing a tracking area from
    /// inside its own callback tears it down while AppKit is still dispatching
    /// through it — the same shape as mutating a collection you are iterating.
    ///
    /// The rebuild was never needed anyway: `.inVisibleRect` tells AppKit to
    /// ignore the `rect:` argument and track the view's visible rect itself, so
    /// the area follows every resize with no help. Passing `.inVisibleRect`
    /// *and* rebuilding on resize was belt-and-braces where the braces were
    /// load-bearing and the belt was a segfault.
    private func installTrackingArea() {
        guard let view = contentView, trackingArea == nil else { return }
        let area = NSTrackingArea(
            rect: .zero,  // ignored: .inVisibleRect
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil)
        view.addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { onHoverChange?(true) }

    override func mouseExited(with event: NSEvent) {
        guard !isResizing else { return }
        onHoverChange?(false)
        NSCursor.arrow.set()
    }

    // MARK: Edges

    private func edge(at point: NSPoint) -> Edge? {
        guard let bounds = contentView?.bounds else { return nil }
        let m = Self.resizeMargin
        // `locationInWindow` has a bottom-left origin. Getting this upside down
        // puts the resize handle on the top edge, which reads as the window
        // fighting the pointer.
        let nearLeft = point.x <= m
        let nearRight = point.x >= bounds.width - m
        let nearBottom = point.y <= m
        switch (nearLeft, nearRight, nearBottom) {
        case (true, _, true): return .bottomLeft
        case (_, true, true): return .bottomRight
        case (true, _, false): return .left
        case (_, true, false): return .right
        case (false, false, true): return .bottom
        default: return nil
        }
    }

    private func cursor(for edge: Edge?) -> NSCursor {
        switch edge {
        case .left, .right: return .resizeLeftRight
        case .bottom: return .resizeUpDown
        // AppKit ships no diagonal resize cursor publicly. Left-right is the
        // honest approximation, since width is what drives this layout.
        case .bottomLeft, .bottomRight: return .resizeLeftRight
        case nil: return .arrow
        }
    }

    // MARK: Event interception

    /// Resize and double-click-to-back are handled HERE, not in `mouseDown` and
    /// friends, and that is the whole reason they work.
    ///
    /// The content is an `NSHostingView`. SwiftUI consumes mouse events inside
    /// it, so an `NSPanel.mouseDown` override never runs for a click that lands
    /// on the card — which is every click. A first version put the resize logic
    /// in `mouseDown`/`mouseDragged` and the bottom edge silently did nothing:
    /// dragging it produced twenty identical heights.
    ///
    /// `sendEvent` sees the event before dispatch, so this can claim the edges
    /// and hand everything else on untouched.
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .mouseMoved:
            if !isResizing { cursor(for: edge(at: event.locationInWindow)).set() }

        case .leftMouseDown:
            if let edge = edge(at: event.locationInWindow) {
                isResizing = true
                resizeEdge = edge
                resizeOrigin = NSEvent.mouseLocation
                resizeStartFrame = frame
                return  // claimed
            }
            // Double-click on dead space sends the player to the back.
            // Interactive elements are excluded via `isDeadSpace`, so
            // double-clicking the scrubber does not make the widget vanish.
            if event.clickCount == 2, let bounds = contentView?.bounds {
                let flipped = CGPoint(
                    x: event.locationInWindow.x, y: bounds.height - event.locationInWindow.y)
                if isDeadSpace?(flipped) ?? false {
                    onSendToBack?()
                    return  // claimed
                }
            }

        case .leftMouseDragged:
            if isResizing {
                performResize()
                return  // claimed
            }

        case .leftMouseUp:
            if isResizing {
                isResizing = false
                resizeEdge = nil
                resizeOrigin = nil
                resizeStartFrame = nil
                // The pointer may have left during the drag; ask rather than
                // assume it is still inside.
                let inside = contentView?.bounds.contains(event.locationInWindow) ?? false
                onHoverChange?(inside)
                return  // claimed
            }

        default:
            break
        }
        super.sendEvent(event)
    }

    private func performResize() {
        guard let start = resizeStartFrame, let origin = resizeOrigin, let edge = resizeEdge
        else { return }

        let here = NSEvent.mouseLocation
        let dx = here.x - origin.x
        // Cocoa's y grows UPWARD and the window is anchored at its top edge, so
        // dragging the bottom edge up (increasing y) must SHORTEN the window.
        // The opposite sign was tested and looked like the drag doing nothing:
        // it grew the budget instead, and the budget is capped at the height the
        // layout needs, so twenty drag steps produced twenty identical heights.
        let dy = here.y - origin.y

        var width = start.width
        var x = start.origin.x
        var height = start.height
        switch edge {
        case .right:
            width = start.width + dx
        case .left:
            width = start.width - dx
            x = start.origin.x + dx
        case .bottom:
            height = start.height - dy
        case .bottomRight:
            width = start.width + dx
            height = start.height - dy
        case .bottomLeft:
            width = start.width - dx
            x = start.origin.x + dx
            height = start.height - dy
        }
        width = max(Self.minimumWidth, width)
        height = max(Self.minimumHeight, height)
        // Dragging the left edge past the minimum must not walk the window
        // sideways: once width is clamped, the origin has to stop moving too.
        if edge == .left || edge == .bottomLeft { x = start.maxX - width }

        // Height is a BUDGET, not a result. Dragging the bottom edge is how the
        // priority list earns its keep: the manager hands this height to the
        // solver, which drops the lowest-priority elements until the rest fit.
        // Width alone never drops anything -- it only makes what is there
        // narrower -- which is why the bottom edge has to work.
        let draggingHeight = edge != .left && edge != .right
        onResize?(CGSize(width: width, height: draggingHeight ? height : -1))
        setFrameOrigin(NSPoint(x: x, y: start.origin.y))
    }
}
