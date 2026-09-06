/*
 * Cadence
 * Copyright (C) 2026 Cadence Contributors
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

/// Knows whether the screen is locked, and tells the panel manager.
///
/// This is the ~60 useful lines of Anchor's `LockScreenManager`. The rest of
/// that file orchestrates weather, timer, reminder and live-activity widgets
/// that Cadence does not have.
@MainActor
final class LockScreenManager: ObservableObject {
    static let shared = LockScreenManager()

    @Published private(set) var isLocked = false

    private var pollTask: Task<Void, Never>?

    private init() {}

    func start() {
        // These two are the canonical signals, and they are *distributed*
        // notifications — they come from loginwindow, not from this process.
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(
            self, selector: #selector(screenLocked),
            name: .init("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(
            self, selector: #selector(screenUnlocked),
            name: .init("com.apple.screenIsUnlocked"), object: nil)

        // macOS sometimes delivers `screenIsUnlocked` well after the user has
        // perceived the unlock, which leaves a lock-screen panel sitting over
        // their desktop. This one usually fires earlier. Both handlers are
        // idempotent, so whichever arrives first wins and the other no-ops.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(screenUnlocked),
            name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        // Reflect the state at launch: starting up while already locked is
        // rare but not impossible, and getting it wrong means the panel never
        // appears for that session.
        if Self.sessionIsLocked() == true { screenLocked() }
    }

    // MARK: Handlers

    @objc private func screenLocked() {
        guard !isLocked else { return }
        isLocked = true
        LockScreenPanelManager.shared.show()
        // Only poll if there is something on screen to take down. The poll
        // exists to hide the panel early when the unlock notification is late;
        // with no panel there is nothing to hide, and waking twice a second for
        // a feature that is off by default is exactly the trap this project
        // keeps recording.
        if Defaults[.enableLockScreenWidget] { startPolling() }
    }

    @objc private func screenUnlocked() {
        guard isLocked else { return }
        isLocked = false
        stopPolling()
        LockScreenPanelManager.shared.hide()
    }

    // MARK: Polling fallback

    /// The canonical state, which is not a notification and cannot be late.
    ///
    /// Returns `nil` when it cannot tell, and the caller treats that as "no
    /// new information". Collapsing unknown to `false` meant one transient
    /// CGSession failure read as an unlock and tore the panel down in the
    /// middle of a locked session, with nothing to put it back until the next
    /// real lock.
    private static func sessionIsLocked() -> Bool? {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return nil }
        return session["CGSSessionScreenIsLocked"] as? Bool
    }

    /// Runs **only while locked**, which is the whole reason it is acceptable
    /// in a project whose first rule is not to poll.
    ///
    /// There is no notification to wait on here — the failure being covered is
    /// precisely a notification that does not arrive — and a screen that is
    /// locked is a screen doing nothing else. It stops the instant the state
    /// flips, so the steady-state cost while the machine is in use is zero.
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.isLocked else { return }
                    if Self.sessionIsLocked() == false { self.screenUnlocked() }
                }
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
