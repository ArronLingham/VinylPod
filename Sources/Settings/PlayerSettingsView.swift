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

import Defaults
import SwiftUI

/// Everything that is not a layout.
///
/// Each control here is read by code outside this file. A `Defaults` key whose
/// only references are its own settings row is a dead switch, and Anchor's
/// audit found four of them; the check is cheap, so do it when adding one.
struct PlayerSettingsView: View {
    @Default(.enablePlayerWidget) private var desktopEnabled
    @Default(.playerWindowLevel) private var windowLevel
    @Default(.playerTintsWithAlbum) private var tinted
    @Default(.playerBackgroundOpacity) private var opacity
    @Default(.hoverGrowsWidget) private var hoverGrows
    @Default(.enableLockScreenWidget) private var lockEnabled
    @Default(.lockWidgetWidth) private var lockWidth
    @Default(.lockFullBackground) private var lockBackground
    @Default(.mediaController) private var source

    var body: some View {
        Form {
            Section("Desktop player") {
                Toggle("Show the desktop player", isOn: $desktopEnabled)
                Picker("Position", selection: $windowLevel) {
                    ForEach(PlayerWindowLevel.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Toggle("Tint with the album colour", isOn: $tinted)
                HStack {
                    Text("Background")
                    Slider(value: $opacity, in: 0...1)
                    Text("\(Int(opacity * 100))%").monospacedDigit().frame(width: 42)
                }
                Toggle("Grow on hover", isOn: $hoverGrows)
                Text("When off, anything you mark as hover-only has to fit in the size it already is.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Lock screen") {
                Toggle("Show on the lock screen", isOn: $lockEnabled)
                Text("Draws above the lock screen using a private system API.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text("Width")
                    Slider(value: $lockWidth, in: 260...620)
                    Text("\(Int(lockWidth))").monospacedDigit().frame(width: 42)
                }
                Picker("Full-screen background", selection: $lockBackground) {
                    ForEach(LockFullBackground.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }

            Section("Source") {
                Picker("Read playback from", selection: $source) {
                    ForEach(MediaControllerType.allCases) { Text($0.localizedName).tag($0) }
                }
                Text("Now Playing covers every app but needs a system API Apple removed in macOS 15.4.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
