// Draws Cadence's app icon and writes an .iconset.
//
// Generated rather than shipped as a binary blob so it is reviewable, editable
// and diffable — and so a public repo carries no opaque art whose provenance
// nobody can check.
//
//   swift scripts/make-icon.swift Sources/Assets.xcassets/AppIcon.appiconset
import AppKit
import Foundation

/// Draws at an exact PIXEL size.
///
/// Not `NSImage(size:)` + `lockFocus()`: that captures at the display's backing
/// scale, so on a retina Mac every image came out twice the size asked for and
/// actool rejected them ("icon_32x32@2x.png is 128x128 but should be 64x64").
/// An explicit `NSBitmapImageRep` has no scale factor to get wrong.
func drawIcon(side: CGFloat) -> Data? {
    let pixels = Int(side)
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: rep)
    else { return nil }
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let ctx = context.cgContext
    ctx.setShouldAntialias(true)

    // macOS icons are drawn inside a rounded square with a margin; matching the
    // system's proportions is what stops it looking oversized in the Dock.
    let inset = side * 0.08
    let box = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let corner = box.width * 0.2237  // Apple's squircle radius ratio

    let plate = NSBezierPath(roundedRect: box, xRadius: corner, yRadius: corner)
    NSGradient(
        starting: NSColor(calibratedRed: 0.42, green: 0.30, blue: 0.55, alpha: 1),
        ending: NSColor(calibratedRed: 0.78, green: 0.34, blue: 0.45, alpha: 1)
    )?.draw(in: plate, angle: 60)

    // The record.
    let discSide = box.width * 0.74
    let disc = CGRect(
        x: box.midX - discSide / 2, y: box.midY - discSide / 2,
        width: discSide, height: discSide)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: side * 0.02, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    NSColor(calibratedWhite: 0.06, alpha: 1).setFill()
    NSBezierPath(ovalIn: disc).fill()
    ctx.restoreGState()

    // Grooves. Same count and spirit as VinylRecordView, so the icon and the
    // thing it stands for look related.
    NSColor(calibratedWhite: 1, alpha: 0.055).setStroke()
    for index in 0..<22 {
        let t = CGFloat(index) / 22
        let r = discSide / 2 * (0.42 + 0.56 * t)
        let path = NSBezierPath(
            ovalIn: CGRect(x: disc.midX - r, y: disc.midY - r, width: r * 2, height: r * 2))
        path.lineWidth = max(0.5, side * 0.0016)
        path.stroke()
    }

    // Label, in the album-art colours.
    let labelSide = discSide * 0.38
    let label = CGRect(
        x: disc.midX - labelSide / 2, y: disc.midY - labelSide / 2,
        width: labelSide, height: labelSide)
    NSGradient(
        starting: NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.42, alpha: 1),
        ending: NSColor(calibratedRed: 0.85, green: 0.30, blue: 0.42, alpha: 1)
    )?.draw(in: NSBezierPath(ovalIn: label), angle: 45)

    // Spindle.
    let spindle = max(2, discSide * 0.035)
    NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
    NSBezierPath(
        ovalIn: CGRect(
            x: disc.midX - spindle / 2, y: disc.midY - spindle / 2,
            width: spindle, height: spindle)
    ).fill()

    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.appiconset"
try? FileManager.default.createDirectory(
    atPath: out, withIntermediateDirectories: true)

// (filename, pixel size) — the full set macOS wants.
let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, pixels) in sizes {
    guard let png = drawIcon(side: pixels) else { continue }
    try? png.write(to: URL(fileURLWithPath: out).appendingPathComponent(name))
}

let contents = """
{
  "images" : [
    {"filename":"icon_16x16.png","idiom":"mac","scale":"1x","size":"16x16"},
    {"filename":"icon_16x16@2x.png","idiom":"mac","scale":"2x","size":"16x16"},
    {"filename":"icon_32x32.png","idiom":"mac","scale":"1x","size":"32x32"},
    {"filename":"icon_32x32@2x.png","idiom":"mac","scale":"2x","size":"32x32"},
    {"filename":"icon_128x128.png","idiom":"mac","scale":"1x","size":"128x128"},
    {"filename":"icon_128x128@2x.png","idiom":"mac","scale":"2x","size":"128x128"},
    {"filename":"icon_256x256.png","idiom":"mac","scale":"1x","size":"256x256"},
    {"filename":"icon_256x256@2x.png","idiom":"mac","scale":"2x","size":"256x256"},
    {"filename":"icon_512x512.png","idiom":"mac","scale":"1x","size":"512x512"},
    {"filename":"icon_512x512@2x.png","idiom":"mac","scale":"2x","size":"512x512"}
  ],
  "info" : {"author":"xcode","version":1}
}
"""
try? contents.write(
    to: URL(fileURLWithPath: out).appendingPathComponent("Contents.json"),
    atomically: true, encoding: .utf8)
print("wrote \(sizes.count) images to \(out)")
