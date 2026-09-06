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
import Foundation

// The layout types live in Sources/Layout/, which imports nothing but Foundation
// and CoreGraphics so that tests/run_gridsolver_tests.sh can compile the real
// files with swiftc. Storing them in `Defaults` needs a conformance, and putting
// `import Defaults` in those files would break the harness — so it lives here.
//
// Every one of these is already Codable, which is all Defaults.Serializable
// requires; these declarations add no behaviour.

extension PlayerLayouts: Defaults.Serializable {}
extension SurfaceLayout: Defaults.Serializable {}
extension ElementPlacement: Defaults.Serializable {}
extension GridGeometry: Defaults.Serializable {}
extension PlayerElement: Defaults.Serializable {}
extension PlayerSurface: Defaults.Serializable {}
extension ElementLayer: Defaults.Serializable {}
extension ElementVisibility: Defaults.Serializable {}
extension ArtworkStyle: Defaults.Serializable {}
