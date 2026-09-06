/*
 * Anchor
 * Derived from Atoll (DynamicIsland), itself derived from boring.notch.
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * Originally from boring.notch project
 * Modified and adapted for Atoll (DynamicIsland)
 * See NOTICE for details.
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

import Foundation



extension Date {
    static var yesterday: Date { return Date().dayBefore }
    static var tomorrow:  Date { return Date().dayAfter }
    var dayBefore: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: noon)!
    }
    var dayAfter: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: noon)!
    }
    var noon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }
    
    var date: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd"
        return dateFormatter.string(from: self)
    }
    
    var month: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        return dateFormatter.string(from: self)
    }
    
    func dayOfTheWeek(dayOfWeek: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE"
        let date = Calendar.current.date(bySetting: .weekday, value: dayOfWeek, of: self) ?? self
        return dateFormatter.string(from: date)
    }
}

extension NSSize {
    var s: String { "\(width.i)×\(height.i)" }
    
    var aspectRatio: Double {
        width / height
    }
    func scaled(by factor: Double) -> CGSize {
        CGSize(width: (width * factor).evenInt, height: (height * factor).evenInt)
    }
    
}

extension Int {
    var s: String {
        String(self)
    }
    var d: Double {
        Double(self)
    }
}

extension Double {
    @inline(__always) @inlinable var intround: Int {
        rounded().i
    }

    /// `Int(exactly:)`, not `Int(self)`.
    ///
    /// `Int(aDouble)` **traps** on NaN and on anything outside Int's range —
    /// not an exception, a hard crash. Anchor took a SIGTRAP from exactly this
    /// shape while drawing elapsed time, because a live stream reports a NaN
    /// duration as a matter of course.
    ///
    /// Nothing calls this today, which is why it is worth fixing now: an
    /// unguarded conversion behind a one-character property name is a trap the
    /// first caller walks into, and they will not be looking.
    @inline(__always) @inlinable var i: Int {
        Int(exactly: rounded(.towardZero)) ?? 0
    }

    var evenInt: Int {
        let x = intround
        return x + x % 2
    }
}

extension CGFloat {
    @inline(__always) @inlinable var intround: Int {
        rounded().i
    }

    /// See the note on `Double.i`. Same trap, same fix.
    @inline(__always) @inlinable var i: Int {
        Int(exactly: rounded(.towardZero)) ?? 0
    }
    
    var evenInt: Int {
        let x = intround
        return x + x % 2
    }
}
