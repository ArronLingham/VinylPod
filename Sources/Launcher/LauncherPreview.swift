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

#if DEBUG

    import AppKit
    import SwiftUI

    /// Shows the launcher card in a window of its own.
    ///
    /// `LauncherPlayerWidget` is the one surface with no host: VinylPod has no
    /// launcher, and it is wired in at Anchor integration. That left it built,
    /// committed, and **never once rendered** — the exact shape of "complete but
    /// unreachable" this project keeps recording, except self-inflicted.
    ///
    /// Debug only, like the lock-screen preview and for the same reason: a
    /// shipped build must not put a window on screen because an environment
    /// variable said so. `scripts/check-debug-hooks.sh` asserts it is gone from
    /// Release.
    ///
    ///     VINYLPOD_PREVIEW_LAUNCHER=1 open -n VinylPod.app
    ///     VINYLPOD_PREVIEW_LAUNCHER=hover open -n VinylPod.app
    @MainActor
    enum LauncherPreview {
        private static var window: NSWindow?

        static func showIfRequested() {
            guard let mode = ProcessInfo.processInfo.environment["VINYLPOD_PREVIEW_LAUNCHER"]
            else { return }

            // The strip Anchor puts this in has a dark HUD backing, so previewing
            // it on a light window would misrepresent the material.
            let host = NSHostingView(
                rootView: LauncherPreviewHost(alwaysShowsControls: mode == "hover"))
            let created = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            created.title = "Launcher widget (preview)"
            created.contentView = host
            created.isReleasedWhenClosed = false
            created.center()
            created.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
            window = created
        }
    }

    private struct LauncherPreviewHost: View {
        let alwaysShowsControls: Bool

        var body: some View {
            ZStack {
                Color(white: 0.13)
                LauncherPlayerWidget(size: .regular)
            }
            .onAppear {
                // Set the preference the widget reads rather than passing a
                // flag, so the preview exercises the real path.
                Defaults[.launcherAlwaysShowsControls] = alwaysShowsControls
            }
        }
    }

    import Defaults

#endif
