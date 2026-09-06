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
    ctx.interpolationQuality = .high

    // Below 48pt the detail stops helping and starts hurting. At 16px the 46
    // grooves average out to grey — the disc stops reading as black vinyl —
    // and the tonearm's pivot becomes a stray white dot in the corner that
    // looks like a rendering error. Apple's own icons simplify at small sizes
    // for the same reason; this is that, in one flag.
    let detailed = side >= 48

    // macOS icons sit inside a rounded square with a margin; matching the
    // system's proportions is what stops it looking oversized in the Dock.
    let inset = side * 0.08
    let box = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let corner = box.width * 0.2237  // Apple's squircle radius ratio
    let plate = NSBezierPath(roundedRect: box, xRadius: corner, yRadius: corner)

    // --- plate -------------------------------------------------------------
    NSGradient(
        starting: NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.44, alpha: 1),
        ending: NSColor(calibratedRed: 0.80, green: 0.33, blue: 0.44, alpha: 1)
    )?.draw(in: plate, angle: 65)

    // A vignette. Flat gradients read as clip art; darkening the corners is
    // most of what makes a drawn plate look lit.
    ctx.saveGState()
    plate.addClip()
    NSGradient(
        colors: [.clear, NSColor.black.withAlphaComponent(0.30)],
        atLocations: [0.45, 1.0],
        colorSpace: .deviceRGB
    )?.draw(
        fromCenter: CGPoint(x: box.midX, y: box.maxY), radius: 0,
        toCenter: CGPoint(x: box.midX, y: box.midY), radius: box.width * 0.78,
        options: [])
    ctx.restoreGState()

    // --- record ------------------------------------------------------------
    let discSide = box.width * 0.70
    let disc = CGRect(
        x: box.midX - discSide / 2, y: box.midY - discSide / 2,
        width: discSide, height: discSide)

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -side * 0.012), blur: side * 0.035,
        color: NSColor.black.withAlphaComponent(0.55).cgColor)
    NSColor(calibratedWhite: 0.05, alpha: 1).setFill()
    NSBezierPath(ovalIn: disc).fill()
    ctx.restoreGState()

    ctx.saveGState()
    NSBezierPath(ovalIn: disc).addClip()

    // Grooves, banded the way a record's tracks are rather than evenly spaced:
    // a few wider gaps read as the separations between songs.
    let grooveCount = detailed ? 46 : 4
    for index in 0..<grooveCount {
        let t = CGFloat(index) / CGFloat(grooveCount)
        let r = discSide / 2 * (0.30 + 0.69 * t)
        let isBand = detailed ? index % 11 == 0 : true
        NSColor(calibratedWhite: 1, alpha: isBand ? 0.16 : 0.055).setStroke()
        let path = NSBezierPath(
            ovalIn: CGRect(x: disc.midX - r, y: disc.midY - r, width: r * 2, height: r * 2))
        path.lineWidth = max(0.4, side * (isBand ? 0.0028 : 0.0014))
        path.stroke()
    }

    // The specular sweep. This is the single thing that makes a drawn record
    // look like vinyl rather than like a black circle: real records throw a
    // soft angled highlight across the disc.
    ctx.saveGState()
    ctx.rotate(by: 0)
    NSGradient(
        colors: [
            .clear,
            NSColor(calibratedWhite: 1, alpha: 0.20),
            NSColor(calibratedWhite: 1, alpha: 0.05),
            .clear,
        ],
        atLocations: [0.30, 0.46, 0.54, 0.70], colorSpace: .deviceRGB
    )?.draw(in: NSBezierPath(ovalIn: disc), angle: 118)
    ctx.restoreGState()

    // Rim light along the top-left edge.
    let rim = NSBezierPath(ovalIn: disc.insetBy(dx: side * 0.004, dy: side * 0.004))
    rim.lineWidth = max(0.6, side * 0.006)
    NSColor(calibratedWhite: 1, alpha: 0.14).setStroke()
    rim.stroke()
    ctx.restoreGState()

    // --- label -------------------------------------------------------------
    let labelSide = discSide * (detailed ? 0.36 : 0.46)
    let label = CGRect(
        x: disc.midX - labelSide / 2, y: disc.midY - labelSide / 2,
        width: labelSide, height: labelSide)
    NSGradient(
        starting: NSColor(calibratedRed: 0.99, green: 0.62, blue: 0.40, alpha: 1),
        ending: NSColor(calibratedRed: 0.86, green: 0.26, blue: 0.42, alpha: 1)
    )?.draw(in: NSBezierPath(ovalIn: label), angle: 55)
    if detailed {
        let labelRing = NSBezierPath(ovalIn: label)
        labelRing.lineWidth = max(0.5, side * 0.003)
        NSColor(calibratedWhite: 0, alpha: 0.22).setStroke()
        labelRing.stroke()
    }

    // --- tonearm -----------------------------------------------------------
    // Dropped at small sizes: see `detailed`.
    if detailed {
    // Angled in from the top right, matching the app's own tonearm so the icon
    // and the thing it stands for look related.
    ctx.saveGState()
    let pivot = CGPoint(x: box.maxX - box.width * 0.155, y: box.maxY - box.height * 0.155)
    // 0.29 of the disc radius out from centre: on the grooves, where a stylus
    // actually rides. At 0.20 the headshell sat on the label, which reads wrong
    // to anyone who has used a turntable.
    let armEnd = CGPoint(x: disc.midX + discSide * 0.29, y: disc.midY + discSide * 0.29)

    ctx.setShadow(
        offset: CGSize(width: 0, height: -side * 0.006), blur: side * 0.018,
        color: NSColor.black.withAlphaComponent(0.45).cgColor)

    let arm = NSBezierPath()
    arm.move(to: pivot)
    arm.line(to: armEnd)
    arm.lineWidth = max(1.0, side * 0.015)
    arm.lineCapStyle = .round
    NSColor(calibratedWhite: 0.26, alpha: 1).setStroke()
    arm.stroke()

    // Headshell.
    let head = side * 0.045
    let headRect = CGRect(
        x: armEnd.x - head / 2, y: armEnd.y - head / 2, width: head, height: head)
    NSColor(calibratedWhite: 0.18, alpha: 1).setFill()
    NSBezierPath(
        roundedRect: headRect, xRadius: head * 0.25, yRadius: head * 0.25
    ).fill()

    // Pivot housing, lit from the same direction as the plate.
    let housing = side * 0.085
    let housingRect = CGRect(
        x: pivot.x - housing / 2, y: pivot.y - housing / 2, width: housing, height: housing)
    NSGradient(
        starting: NSColor(calibratedWhite: 0.97, alpha: 1),
        ending: NSColor(calibratedWhite: 0.55, alpha: 1)
    )?.draw(in: NSBezierPath(ovalIn: housingRect), angle: 300)
    ctx.restoreGState()
    }

    // --- spindle -----------------------------------------------------------
    if detailed {
        let spindle = max(1.6, discSide * 0.030)
        NSColor(calibratedWhite: 0.95, alpha: 1).setFill()
        NSBezierPath(
            ovalIn: CGRect(
                x: disc.midX - spindle / 2, y: disc.midY - spindle / 2,
                width: spindle, height: spindle)
        ).fill()
    }

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
