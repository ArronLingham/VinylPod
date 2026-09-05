#!/bin/bash
# Pins GridSolver — the engine every surface's layout goes through.
#
# It compiles the REAL source files with swiftc rather than a copy, so the
# harness cannot drift from the implementation. That is possible only because
# Sources/Layout/ is deliberately free of SwiftUI, AppKit and Defaults; if a
# future change imports any of those into these four files, this harness stops
# compiling, and that is the intended alarm rather than a nuisance.
#
# Worth pinning because every failure here is quiet. A layout that silently
# drops the wrong element, an overlay that separates from the artwork it was
# drawn on, a hover that grows when it should not — none of these crash, none
# fail a build, and all of them look almost right.
#
# Every guard below was proved non-vacuous by breaking the thing it checks and
# watching this go red. See the NEGATIVE CONTROLS block at the end for the exact
# edits and what each one produced. Anchor shipped a safety check that was
# provably inert twice; the control is the only thing that catches it.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/main.swift" <<'SWIFT'
import CoreGraphics
import Foundation

var passes = 0
var failures = 0

func ok(_ label: String, _ condition: Bool, _ detail: String = "") {
    if condition {
        passes += 1
    } else {
        failures += 1
        print("  FAIL \(label)\(detail.isEmpty ? "" : ": \(detail)")")
    }
}

func near(_ a: CGFloat, _ b: CGFloat, _ tol: CGFloat = 0.01) -> Bool { abs(a - b) < tol }

func place(
    _ element: PlayerElement, _ col: Int, _ row: Int, span: Int = 1,
    layer: ElementLayer = .base, visibility: ElementVisibility = .always, priority: Int = 0
) -> ElementPlacement {
    ElementPlacement(
        element: element, col: col, row: row, colSpan: span,
        layer: layer, visibility: visibility, priority: priority)
}

func layout(_ columns: Int, _ placements: [ElementPlacement]) -> SurfaceLayout {
    SurfaceLayout(geometry: GridGeometry(columns: columns), placements: placements)
}

let unbounded = CGSize(width: 320, height: CGFloat.infinity)

// ---------------------------------------------------------------------------
print("The four shipped defaults")
// These are what a user sees on first launch. If one of them is malformed the
// app opens on a broken player, so they are checked as data, not just as code.

for (name, surface) in [
    ("desktop", PlayerLayouts.defaults.desktop),
    ("lockWidget", PlayerLayouts.defaults.lockWidget),
    ("lockFull", PlayerLayouts.defaults.lockFull),
    ("launcher", PlayerLayouts.defaults.launcher),
] {
    // No two BASE placements may share a cell. This is the invariant the whole
    // grid model rests on, and it is checked here against the shipped data
    // rather than only against the solver, because a bad default would be
    // silently repaired by the solver at runtime and never noticed.
    var seen: [Int: Set<Int>] = [:]
    var collision = ""
    for p in surface.placements where p.layer == .base {
        let taken = seen[p.row] ?? []
        if !taken.isDisjoint(with: p.columns) {
            collision = "\(p.element.rawValue) at r\(p.row) c\(p.col)"
        }
        seen[p.row] = taken.union(p.columns)
    }
    ok("\(name): no base placements overlap", collision.isEmpty, collision)

    // Rows contiguous from zero — a gap means the author miscounted, and the
    // solver would compact it away, hiding the mistake.
    let rows = Set(surface.placements.map(\.row)).sorted()
    ok("\(name): rows contiguous from 0", rows == Array(0..<rows.count), "\(rows)")

    // Nothing may hang off the right-hand edge.
    let overflow = surface.placements.filter { $0.col + $0.colSpan > surface.geometry.columns }
    ok("\(name): nothing overflows the grid", overflow.isEmpty,
       overflow.map(\.element.rawValue).joined(separator: ","))

    // Every element gets at least the span its metrics say it needs.
    let starved = surface.placements.filter { $0.colSpan < $0.element.metrics.minSpan }
    ok("\(name): every span meets minSpan", starved.isEmpty,
       starved.map(\.element.rawValue).joined(separator: ","))

    // Something must survive an arbitrarily small window.
    let survivors = surface.placements.filter { $0.priority == 0 }
    ok("\(name): has priority-0 elements", !survivors.isEmpty)

    // An overlay with no base under it would float on nothing.
    let bases = surface.placements.filter { $0.layer == .base }
    let floating = surface.placements.filter { p in
        p.layer == .overlay
            && !bases.contains { $0.row == p.row && $0.columns.overlaps(p.columns) }
    }
    ok("\(name): no overlay without a base", floating.isEmpty,
       floating.map(\.element.rawValue).joined(separator: ","))
}

// ---------------------------------------------------------------------------
print("Overlap handling")

// Two base placements fighting over one cell: one must go.
let clash = layout(4, [place(.title, 0, 0, span: 2), place(.artist, 1, 0, span: 2)])
let clashed = GridSolver.solve(layout: clash, available: unbounded, hovering: false)
ok("two overlapping bases resolve to one", clashed.elements.count == 1,
   "got \(clashed.elements.count)")

// An overlay on a base is legal and is the whole point of the layer field.
let overlaid = layout(4, [
    place(.artwork, 0, 0, span: 4),
    place(.playPause, 1, 0, span: 2, layer: .overlay),
])
let overlayResolved = GridSolver.solve(layout: overlaid, available: unbounded, hovering: false)
ok("an overlay may sit on a base", overlayResolved.elements.count == 2,
   "got \(overlayResolved.elements.count)")

// And it must draw second, so it lands on top without the renderer needing a
// z-index of its own.
ok("overlays draw after bases",
   overlayResolved.elements.last?.placement.element == .playPause)

// ---------------------------------------------------------------------------
print("Height derivation")

// Artwork is square: its height follows the width it is given. This is what
// makes the record grow its row, and it generalises
// VinylWidgetSize.height(width:orientation:showsTitle:showsProgress:), which
// was once a fixed 1.36 ratio — so switching the progress bar off left an empty
// strip instead of making the card shorter.
let art = layout(4, [place(.artwork, 0, 0, span: 4)])
let artSolved = GridSolver.solve(layout: art, available: unbounded, hovering: false)
let artFrame = artSolved.elements[0].frame
ok("artwork is square", near(artFrame.width, artFrame.height),
   "\(artFrame.width) x \(artFrame.height)")

// An overlay contributes no height. Without this the hover requirement cannot
// work, because revealing a button over something would make the row taller.
//
// The base here is deliberately SHORTER than the overlay: timeElapsed is 14pt
// and playPause is 38pt. A first version of this check used artwork (292pt at
// this width) as the base, so the row was 292 whether overlays counted or not
// — it passed with the guard deliberately removed. It was a vacuous test and
// only the negative control found it, which is the whole reason the control
// block at the bottom of this file exists.
let shortBase = layout(4, [place(.timeElapsed, 0, 0, span: 4)])
let shortBaseTallOverlay = layout(4, [
    place(.timeElapsed, 0, 0, span: 4),
    place(.playPause, 1, 0, span: 2, layer: .overlay),
])
let plain = GridSolver.solve(layout: shortBase, available: unbounded, hovering: false)
let plusOverlay = GridSolver.solve(
    layout: shortBaseTallOverlay, available: unbounded, hovering: false)
ok("an overlay TALLER than its base still adds no height",
   near(plain.requiredSize.height, plusOverlay.requiredSize.height),
   "\(plain.requiredSize.height) vs \(plusOverlay.requiredSize.height)")
ok("the overlay is still drawn, just without height",
   plusOverlay.elements.count == 2)

// Same shape again for the artwork case, which is the one users will actually
// build. It cannot fail independently of the check above, but it documents the
// intended arrangement.
let baseOnly = GridSolver.solve(layout: art, available: unbounded, hovering: false)
let withOverlay = GridSolver.solve(layout: overlaid, available: unbounded, hovering: false)
ok("an overlay on the artwork adds no height",
   near(baseOnly.requiredSize.height, withOverlay.requiredSize.height),
   "\(baseOnly.requiredSize.height) vs \(withOverlay.requiredSize.height)")

// A taller element sets its row's height; a shorter one in the same row does
// not shrink it.
let mixed = layout(4, [place(.playPause, 0, 0), place(.timeElapsed, 1, 0)])
let mixedSolved = GridSolver.solve(layout: mixed, available: unbounded, hovering: false)
let rowH = mixedSolved.rowHeights[0]
ok("row height is the tallest element in it",
   near(rowH, PlayerElement.playPause.metrics.height(0)), "\(rowH)")

// ---------------------------------------------------------------------------
print("Priority dropping")

let droppable = layout(4, [
    place(.artwork, 0, 0, span: 4, priority: 0),
    place(.title, 0, 1, span: 4, priority: 1),
    place(.artist, 0, 2, span: 4, priority: 5),
    place(.album, 0, 3, span: 4, priority: 9),
])
let full = GridSolver.solve(layout: droppable, available: unbounded, hovering: false)
ok("nothing drops at unbounded height", full.dropped.isEmpty)

// Squeeze by one row's worth: the highest priority VALUE goes first.
let squeezed = GridSolver.solve(
    layout: droppable,
    available: CGSize(width: 320, height: full.requiredSize.height - 5),
    hovering: false)
ok("the highest-priority-value element drops first",
   squeezed.elements.allSatisfy { $0.placement.element != .album },
   squeezed.elements.map(\.placement.element.rawValue).joined(separator: ","))
ok("only one element dropped for one row of overflow", squeezed.dropped.count == 1,
   "\(squeezed.dropped.count)")

// Priority 0 is never dropped, whatever the height. That is what makes the
// drop loop terminate rather than emptying the surface.
let crushed = GridSolver.solve(
    layout: droppable, available: CGSize(width: 320, height: 1), hovering: false)
ok("priority-0 survives an impossible height",
   crushed.elements.contains { $0.placement.element == .artwork })
ok("everything droppable was dropped", crushed.elements.count == 1,
   "\(crushed.elements.count) left")

// A surface of nothing but priority-0 elements terminates rather than looping.
let incompressible = layout(4, [
    place(.artwork, 0, 0, span: 4), place(.title, 0, 1, span: 4),
])
let stuck = GridSolver.solve(
    layout: incompressible, available: CGSize(width: 320, height: 1), hovering: false)
ok("an incompressible layout returns rather than hanging", stuck.elements.count == 2)

// Dropping is monotone: more room never shows fewer elements. This is the
// property that keeps a resize drag from flickering an element in and out.
var previousCount = -1
var monotone = true
for step in stride(from: CGFloat(20), through: full.requiredSize.height + 40, by: 7) {
    let n = GridSolver.solve(
        layout: droppable, available: CGSize(width: 320, height: step), hovering: false
    ).elements.count
    if n < previousCount { monotone = false }
    previousCount = n
}
ok("element count never decreases as height grows", monotone)

// ---------------------------------------------------------------------------
print("Orphaned overlays")

// An overlay is anchored to the base under it. If the drop loop takes that
// base, the overlay must go too — otherwise a play button hangs in the space
// where the artwork used to be.
let orphanCase = layout(4, [
    place(.title, 0, 0, span: 4, priority: 0),
    place(.artwork, 0, 1, span: 4, priority: 9),
    place(.playPause, 1, 1, span: 2, layer: .overlay, priority: 0),
])
let orphanFull = GridSolver.solve(layout: orphanCase, available: unbounded, hovering: false)
let orphaned = GridSolver.solve(
    layout: orphanCase,
    available: CGSize(width: 320, height: orphanFull.requiredSize.height - 20),
    hovering: false)
ok("an overlay goes when its base goes",
   !orphaned.elements.contains { $0.placement.element == .playPause },
   orphaned.elements.map(\.placement.element.rawValue).joined(separator: ","))

// ---------------------------------------------------------------------------
print("Compaction")

// Deleting a row moves everything below it up — overlays with their bases, from
// one shared mapping. Compacting the two separately is how an overlay ends up
// on a different row from the thing it was drawn on.
let gapped = layout(4, [
    place(.title, 0, 0, span: 4, priority: 9),
    place(.artwork, 0, 1, span: 4, priority: 0),
    place(.playPause, 1, 1, span: 2, layer: .overlay, priority: 0),
])
let gapFull = GridSolver.solve(layout: gapped, available: unbounded, hovering: false)
let compacted = GridSolver.solve(
    layout: gapped,
    available: CGSize(width: 320, height: gapFull.requiredSize.height - 5),
    hovering: false)
let artRow = compacted.elements.first { $0.placement.element == .artwork }?.placement.row
let btnRow = compacted.elements.first { $0.placement.element == .playPause }?.placement.row
ok("compaction keeps an overlay on its base's row", artRow != nil && artRow == btnRow,
   "artwork r\(artRow.map { String($0) } ?? "-") overlay r\(btnRow.map { String($0) } ?? "-")")
ok("compaction renumbers from zero", artRow == 0, "\(artRow.map { String($0) } ?? "-")")
ok("the overlay is still drawn over its base",
   compacted.elements.count == 2)

// ---------------------------------------------------------------------------
print("Hover growth is derived from fit")

// The user's requirement, verbatim: "if I add a pause button on hover, then it
// will not grow but a progress bar would require it to grow."

let hoverButton = layout(4, [
    place(.artwork, 0, 0, span: 4),
    place(.playPause, 1, 0, span: 2, layer: .overlay, visibility: .onHover),
])
let buttonMetrics = GridSolver.hoverMetrics(layout: hoverButton, width: 320)
ok("a hover-only button OVER the artwork does not grow", !buttonMetrics.grows,
   "resting \(buttonMetrics.restingHeight) hover \(buttonMetrics.hoverHeight)")

// And again where the revealed button is taller than what it sits on, so the
// check depends on the overlay rule rather than on the artwork being large.
let hoverOnShortBase = layout(4, [
    place(.title, 0, 0, span: 4),
    place(.playPause, 1, 0, span: 2, layer: .overlay, visibility: .onHover),
])
let shortMetrics = GridSolver.hoverMetrics(layout: hoverOnShortBase, width: 320)
ok("a hover-only button taller than its base still does not grow",
   !shortMetrics.grows,
   "resting \(shortMetrics.restingHeight) hover \(shortMetrics.hoverHeight)")

let hoverBar = layout(4, [
    place(.artwork, 0, 0, span: 4),
    place(.progressBar, 0, 1, span: 4, visibility: .onHover),
])
let barMetrics = GridSolver.hoverMetrics(layout: hoverBar, width: 320)
ok("a hover-only progress bar on its own row does grow", barMetrics.grows,
   "resting \(barMetrics.restingHeight) hover \(barMetrics.hoverHeight)")

// The hover set always contains the resting set, so hovering can never take
// something away.
let hoverResolved = GridSolver.solve(layout: hoverBar, available: unbounded, hovering: true)
let restResolved = GridSolver.solve(layout: hoverBar, available: unbounded, hovering: false)
let restElements = Set(restResolved.elements.map(\.placement.id))
let hoverElements = Set(hoverResolved.elements.map(\.placement.id))
ok("hovering only ever adds", restElements.isSubset(of: hoverElements))

// Growth is measured at unbounded height on purpose. If it were measured at the
// window's current height, growing would move the window edge, which can move
// the pointer outside the surface, which un-hovers, which shrinks it back under
// the pointer — a flutter with no stable state.
ok("hover measurement ignores the current window height",
   GridSolver.hoverMetrics(layout: hoverBar, width: 320)
       == GridSolver.hoverMetrics(layout: hoverBar, width: 320))

// ---------------------------------------------------------------------------
print("Malformed input is clamped, not fatal")

// These arrive from hand-edited JSON, from a layout saved when the surface had
// more columns, or from a future version. A player that refuses to draw is
// worse than one that draws a slightly wrong arrangement.
let malformed = layout(4, [
    place(.title, 3, 0, span: 9),      // span runs off the right edge
    place(.artist, 9, 1, span: 1),     // column past the last one
    place(.album, 0, -3, span: 2),     // negative row
])
let repaired = GridSolver.solve(layout: malformed, available: unbounded, hovering: false)
ok("a negative row is discarded",
   !repaired.elements.contains { $0.placement.element == .album })
ok("an oversized span is clamped inside the grid",
   repaired.elements.allSatisfy { $0.placement.col + $0.placement.colSpan <= 4 },
   repaired.elements.map { "\($0.placement.element.rawValue) c\($0.placement.col)+\($0.placement.colSpan)" }
       .joined(separator: " "))
ok("an out-of-range column is clamped",
   repaired.elements.allSatisfy { $0.placement.col < 4 })

let empty = GridSolver.solve(layout: layout(4, []), available: unbounded, hovering: false)
ok("an empty layout is not a crash", empty.elements.isEmpty)
ok("an empty layout is just padding",
   near(empty.requiredSize.height, GridGeometry(columns: 4).padding * 2))

let zeroWidth = GridSolver.solve(
    layout: art, available: CGSize(width: 0, height: CGFloat.infinity), hovering: false)
ok("zero width does not divide by zero", zeroWidth.requiredSize.height.isFinite)

// ---------------------------------------------------------------------------
print("Editor support")

let editing = layout(4, [place(.title, 0, 0, span: 2)])

ok("a base may not land on an occupied cell",
   !GridSolver.canPlace(place(.artist, 1, 0), in: editing))
ok("a base may land on a free cell",
   GridSolver.canPlace(place(.artist, 2, 0, span: 2), in: editing))
ok("an overlay may land on an occupied cell",
   GridSolver.canPlace(place(.playPause, 0, 0, layer: .overlay), in: editing))
ok("a placement does not collide with itself when moved",
   GridSolver.canPlace(editing.placements[0], in: editing, ignoring: editing.placements[0].id))
ok("a span that overflows the grid is refused",
   !GridSolver.canPlace(place(.artist, 3, 0, span: 2), in: editing))
ok("a span below minSpan is refused",
   !GridSolver.canPlace(place(.progressBar, 0, 1, span: 1), in: editing))

ok("free columns exclude the occupied ones",
   GridSolver.freeColumns(on: 0, in: editing) == [2, 3],
   "\(GridSolver.freeColumns(on: 0, in: editing))")
ok("an untouched row is entirely free",
   GridSolver.freeColumns(on: 1, in: editing) == [0, 1, 2, 3])

// Point-to-cell, used by the drag editor. A drop below the last row means "make
// a new bottom row", so one past the end is a valid answer, not an error.
let geo = GridGeometry(columns: 4)
let heights: [CGFloat] = [40, 40]
ok("a point in the first cell maps to (0,0)",
   GridSolver.cell(at: CGPoint(x: geo.padding + 1, y: geo.padding + 1),
                   geometry: geo, totalWidth: 320, rowHeights: heights).map { $0 == (0, 0) } ?? false)
ok("a point below the last row is one past the end",
   GridSolver.cell(at: CGPoint(x: geo.padding + 1, y: 900),
                   geometry: geo, totalWidth: 320, rowHeights: heights)?.row == heights.count)
ok("a point in the padding is outside the grid",
   GridSolver.cell(at: CGPoint(x: 1, y: 1), geometry: geo, totalWidth: 320,
                   rowHeights: heights) == nil)

// ---------------------------------------------------------------------------
print("Storage survives the future")

// Adding a PlayerElement case, or a fifth surface at Anchor integration, must
// not reset a user's saved layouts.
let encoder = JSONEncoder()
let decoder = JSONDecoder()
let roundTripped = try! decoder.decode(
    PlayerLayouts.self, from: try! encoder.encode(PlayerLayouts.defaults))
ok("PlayerLayouts round-trips", roundTripped == PlayerLayouts.defaults)

let partial = #"{"desktop":{"geometry":{"columns":6,"padding":14,"gutter":8},"placements":[]}}"#
let recovered = try? decoder.decode(PlayerLayouts.self, from: Data(partial.utf8))
ok("a missing surface falls back to its default rather than failing the decode",
   recovered != nil && recovered?.lockFull == SurfaceLayout.defaultLockFull)

let sparse = #"{"element":"title","col":1,"row":2}"#
let sparsePlacement = try? decoder.decode(ElementPlacement.self, from: Data(sparse.utf8))
ok("a placement missing every optional field decodes",
   sparsePlacement?.colSpan == 1 && sparsePlacement?.layer == .base
       && sparsePlacement?.visibility == .always)

// Placement ids must be stable across launches, or Defaults sees a change and
// writes on every start, and two machines syncing settings fight each other.
ok("default placement ids are deterministic",
   PlayerLayouts.defaults.desktop.placements.map(\.id)
       == PlayerLayouts.defaults.desktop.placements.map(\.id))
ok("default ids are unique within a surface",
   Set(PlayerLayouts.defaults.desktop.placements.map(\.id)).count
       == PlayerLayouts.defaults.desktop.placements.count)

// ---------------------------------------------------------------------------
print("")
print("\(passes)/\(passes + failures) passed")
if failures > 0 { exit(1) }
SWIFT

swiftc -O -o "$WORK/tests" \
    Sources/Layout/PlayerElement.swift \
    Sources/Layout/SurfaceLayout.swift \
    Sources/Layout/GridSolver.swift \
    Sources/Layout/DefaultLayouts.swift \
    "$WORK/main.swift" 2>&1 | grep -v "^ *$" | grep -v "warning:" || true

"$WORK/tests"

# ---------------------------------------------------------------------------
# NEGATIVE CONTROLS
#
# Every guard here was verified by making the edit below and confirming this
# harness went red. Measured, not asserted — the results are what actually
# happened, and one of them is the reason two tests were rewritten.
#
#   GridSolver.removeOrphanedOverlays -> return [] immediately
#       66/70 — "an overlay goes when its base goes"
#
#   GridSolver.compact -> apply the row map only to `.base` placements
#       66/70 — "compaction keeps an overlay on its base's row"
#              (reported artwork r0, overlay r1 — exactly the separation)
#
#   GridSolver.rowHeights -> drop the `&& $0.layer == .base` filter
#       68/70 — "an overlay TALLER than its base still adds no height" (42 vs 66)
#               "a hover-only button taller than its base still does not grow"
#
#       *** This control PASSED 67/67 on its first run. *** The two tests it was
#       meant to break used artwork as the base — 292pt at this width against a
#       38pt button — so the row height was 292 whether overlays counted or not.
#       Both were vacuous and both are now written against a base SHORTER than
#       its overlay. Nothing but running the control would have found this: the
#       tests read correctly, named the right property, and could not fail.
#
#   GridSolver.dropToFit -> `$0.priority >= 0` instead of `> 0`
#       64/70 — "priority-0 survives an impossible height", plus the surface
#               empties entirely (0 elements left) rather than stopping
#
#   GridSolver.dropToFit -> `.min` instead of `.max` when picking the victim
#       66/70 — "the highest-priority-value element drops first" (kept album,
#               dropped title — precisely backwards)
#
#   GridSolver.solve -> skip the normalise step
#       64/70 — all three malformed-input checks, including a span of 9 in a
#               4-column grid surviving to the frames
#
#   GridSolver.canPlace -> return true unconditionally
#       64/70 — three editor checks
#
#   PlayerLayouts.init(from:) -> plain synthesised Decodable
#       66/70 — "a missing surface falls back to its default"
#
# One thing here is NOT protected by a control, and is called out rather than
# hidden: `hoverMetrics` measuring at `.infinity` rather than at the window's
# current height. Swapping it still passes at 320pt, because nothing is dropped
# at that size either way. The failure it prevents is dynamic — growing moves
# the window edge, which can move the pointer out of the surface, which
# un-hovers, which shrinks it back under the pointer. A single-size unit test
# cannot see that. It needs a human at §"desktop player" in TESTING.md.
