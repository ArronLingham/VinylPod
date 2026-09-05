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

/// Owns the settings window.
///
/// VinylPod used a SwiftUI `Settings` scene and drove it with
/// `NSApp.sendAction(Selector(("showSettingsWindow:")))`. That did nothing:
/// the app is `LSUIElement`, so there is no key window and the action found no
/// responder — pressing Settings in the menu produced no window and no error,
/// and `AXUIElementCopyAttributeValue(kAXWindowsAttribute)` confirmed only the
/// player panel existed.
///
/// Owning an ordinary `NSWindow` sidesteps the responder chain entirely, and an
/// accessory app has to raise itself to the front anyway.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        // An accessory app is not in the Dock and cannot be brought forward by
        // clicking it, so it has to promote itself while a real window is up.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        if window == nil {
            let created = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            created.title = "VinylPod"
            created.isReleasedWhenClosed = false
            created.center()
            created.contentView = NSHostingView(rootView: SettingsRootView())
            created.delegate = SettingsWindowDelegate.shared
            window = created
        }
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Drops back to accessory when the window closes, so VinylPod leaves the Dock
/// and the menu bar again rather than sitting there like an ordinary app.
@MainActor
final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
