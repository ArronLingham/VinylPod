/*
 * VinylPod
 * Derived from Anchor, itself derived from Atoll (DynamicIsland) and boring.notch.
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
import Combine
import SwiftUI

extension Notification.Name {
    /// Posted when playback moves to a different track. Surfaces observe this
    /// if they want to react; nothing observes it yet, which is deliberate.
    static let vinylPodTrackDidChange = Notification.Name("VinylPod.trackDidChange")
}

@main
struct VinylPodApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // No WindowGroup: VinylPod is a menu-bar app whose surfaces are all
        // borderless panels. A Settings scene gives ⌘, for free.
        Settings {
            SettingsRootView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Never construct a manager from a stored property here.
    ///
    /// SwiftUI builds the delegate on the main thread *before* the run loop
    /// starts, so any singleton that blocks in `init` deadlocks the whole app
    /// at launch and `applicationDidFinishLaunching` never runs. Anchor lost
    /// several sessions to exactly this, and the symptom is not a crash — the
    /// process is alive and looks healthy while being completely hung.
    ///
    /// Everything below is `lazy` for that reason. Keep it that way, and defer
    /// blocking work in any new manager's `init` with `DispatchQueue.main.async`.
    private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()
        // Touching `shared` builds it; its `init` wires the controllers.
        // Deferred off the launch path because `init` reaches AppleScript and
        // CoreAudio, and blocking here is what deadlocks a SwiftUI delegate.
        DispatchQueue.main.async {
            _ = MusicManager.shared
            PlayerWindowManager.shared.start()
        }
    }

    private func setUpStatusItem() {
        statusItem.button?.image = NSImage(
            systemSymbolName: "opticaldisc.fill", accessibilityDescription: "VinylPod")
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let nowPlaying = NSMenuItem(title: "Nothing playing", action: nil, keyEquivalent: "")
        nowPlaying.tag = Self.nowPlayingTag
        menu.addItem(nowPlaying)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit VinylPod", action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        menu.delegate = self
        return menu
    }

    private static let nowPlayingTag = 1

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}

extension AppDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // AppKit calls this on the main thread; `assumeIsolated` says so rather
        // than deferring with a Task, which would not run — the app is on its
        // way out and the run loop stops before a hop could be serviced.
        MainActor.assumeIsolated { PlayerWindowManager.shared.persistFrame() }
    }
}

extension AppDelegate: NSMenuDelegate {
    /// Read the track when the menu opens rather than subscribing to
    /// `MusicManager` — a status item that is closed 99.9% of the time has no
    /// business re-rendering on every publish.
    func menuWillOpen(_ menu: NSMenu) {
        guard let item = menu.item(withTag: Self.nowPlayingTag) else { return }
        let music = MusicManager.shared
        item.title = music.isPlayerIdle
            ? "Nothing playing"
            : "\(music.songTitle) — \(music.artistName)"
    }
}

/// Placeholder until the layout editor lands in Phase 2.
struct SettingsRootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "opticaldisc.fill").font(.system(size: 40))
            Text("VinylPod").font(.title2.weight(.semibold))
            Text("Layout editor arrives in Phase 2.")
                .foregroundStyle(.secondary)
        }
        .frame(width: 420, height: 220)
    }
}
