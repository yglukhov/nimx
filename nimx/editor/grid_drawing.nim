import nimx/context
import nimx/types

proc drawGrid*(bounds: Rect, gridSize: Size, shift = zeroSize) =
    let c = currentContext()
    c.strokeWidth = 0
    var r = newRect(0, 0, 1, bounds.height)
    if gridSize.width > 0:
        let n = int((bounds.width - bounds.x - shift.width) / gridSize.width)
        for x in 0 .. n:
            r.origin.x = bounds.x + shift.width + Coord(x) * gridSize.width
            c.drawRect(r)
    if gridSize.height > 0:
        r.origin.x = 0
        r.size.width = bounds.width
        r.size.height = 1
        let n = int((bounds.height - bounds.y - shift.height) / gridSize.height)
        for y in 0 .. n:
            r.origin.y = bounds.y + shift.height + Coord(y) * gridSize.height
            c.drawRect(r)
