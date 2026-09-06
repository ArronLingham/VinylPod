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

import ServiceManagement
import SwiftUI

/// Start VinylPod when the user logs in.
///
/// `SMAppService.mainApp`, not a `LaunchAtLogin` package and not a login-item
/// helper bundle: the modern API needs no extra target, no helper to keep in
/// sync with the main app's signature, and it puts the toggle in System
/// Settings › Login Items where the user expects to find and revoke it.
///
/// **The real state lives in the system, not in `Defaults`.** A stored boolean
/// would drift the moment someone turned it off in System Settings, and the
/// checkbox would then lie. `isEnabled` reads `SMAppService.status` every time.
@MainActor
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    private init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns the error rather than swallowing it.
    ///
    /// Registration genuinely fails in normal use — an unsigned build, an app
    /// still in `~/Downloads`, or a user who has denied it — and a toggle that
    /// silently springs back with no explanation is worse than one that says
    /// why.
    @discardableResult
    func set(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            objectWillChange.send()
            return nil
        } catch {
            objectWillChange.send()
            return error.localizedDescription
        }
    }

    /// What System Settings would show, for the settings row to explain itself.
    var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled: return String(localized: "On")
        case .requiresApproval:
            return String(localized: "Waiting for approval in System Settings › Login Items")
        case .notFound: return String(localized: "Unavailable for this build")
        case .notRegistered: return String(localized: "Off")
        @unknown default: return String(localized: "Unknown")
        }
    }
}
