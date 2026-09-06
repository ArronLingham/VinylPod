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
    @Default(.lockWidgetVerticalOffset) private var lockOffset
    @Default(.enableLyrics) private var lyricsEnabled
    @Default(.showInDock) private var showInDock
    @StateObject private var launchAtLogin = LaunchAtLogin.shared
    @State private var launchError: String?
    @Default(.visualizerBarCount) private var visualizerBars
    @Default(.coloredSpectrogram) private var colouredSpectrogram
    @Default(.enableRealTimeWaveform) private var realTimeWaveform
    @Default(.lyricsOffsetSeconds) private var lyricsOffset
    @Default(.lyricsTranslationEnabled) private var translateLyrics
    @Default(.musicSkipBehavior) private var skipBehavior
    @Default(.spotifySPDCCookie) private var spotifyCookie
    @Default(.lyricsVisibleLines) private var lyricLines
    @Default(.colorExtractionMode) private var colourMode
    @Default(.sliderColor) private var sliderColour
    @Default(.lockScreenMusicFullscreenVideoArtwork) private var canvasVideo

    var body: some View {
        Form {
            Section("General") {
                Toggle(
                    "Open Cadence at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchError = launchAtLogin.set($0) }))
                Toggle("Show in the Dock", isOn: $showInDock)
                Text("Off by default: Cadence lives in the menu bar. Turning this on also puts it in the ⌘Tab switcher.")
                    .font(.caption).foregroundStyle(.secondary)
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                } else {
                    Text(launchAtLogin.statusDescription)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Desktop player") {
                Toggle("Show the desktop player", isOn: $desktopEnabled)
                Picker("Position", selection: $windowLevel) {
                    ForEach(PlayerWindowLevel.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Toggle("Tint with the album colour", isOn: $tinted)
                Picker("Colour taken from the artwork by", selection: $colourMode) {
                    Text("Average").tag(ColorExtractionMode.legacy)
                    Text("Most vibrant").tag(ColorExtractionMode.vibrant)
                }
                Picker("Progress bar colour", selection: $sliderColour) {
                    ForEach(SliderColorEnum.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                }
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
                HStack {
                    Text("Vertical offset")
                    Slider(value: $lockOffset, in: -240...240)
                    Text("\(Int(lockOffset))").monospacedDigit().frame(width: 42)
                }
                Toggle("Use Spotify Canvas video when there is one", isOn: $canvasVideo)
                Picker("Full-screen background", selection: $lockBackground) {
                    ForEach(LockFullBackground.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }

            Section("Elements") {
                Picker("Skip buttons", selection: $skipBehavior) {
                    ForEach(MusicSkipBehavior.allCases) { Text($0.displayName).tag($0) }
                }
                Stepper("Visualiser bars: \(visualizerBars)", value: $visualizerBars, in: 2...12)
                Toggle("Colour the visualiser from the album", isOn: $colouredSpectrogram)
                Toggle("Real-time waveform", isOn: $realTimeWaveform)
                Text("Reads system audio through a CoreAudio tap, and only while a visualiser is on screen.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Lyrics") {
                Toggle("Fetch lyrics", isOn: $lyricsEnabled)
                Text("Needed by the Lyrics element. Off by default because it fetches from the network.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Translate lyrics", isOn: $translateLyrics)
                HStack {
                    Text("Timing offset")
                    Slider(value: $lyricsOffset, in: -2...2)
                    Text(String(format: "%+.1fs", lyricsOffset)).monospacedDigit().frame(width: 52)
                }
                Text("Negative shows each line earlier. Synced lyrics are rarely perfectly aligned.")
                    .font(.caption).foregroundStyle(.secondary)
                Stepper(
                    lyricLines == 0 ? "Visible lines: as many as fit" : "Visible lines: \(lyricLines)",
                    value: $lyricLines, in: 0...9)
            }

            Section("Source") {
                Picker("Read playback from", selection: $source) {
                    ForEach(MediaControllerType.allCases) { Text($0.localizedName).tag($0) }
                }
                Text("Now Playing covers every app but needs a system API Apple removed in macOS 15.4.")
                    .font(.caption).foregroundStyle(.secondary)
                if source == .spotify {
                    SecureField("Spotify sp_dc cookie", text: $spotifyCookie)
                    Text("Optional. Only needed for lyrics and Canvas artwork; playback works without it. A SecureField because this is a credential.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
