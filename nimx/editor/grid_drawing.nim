import nimx.context
import nimx.types

proc drawGrid*(bounds: Rect, gridSize: Size) =
    let c = currentContext()
    c.strokeWidth = 0
    var r = newRect(0, 0, 1, bounds.height)
    if gridSize.width > 0:
        for x in countup(0, int(bounds.width), int(gridSize.width)):
            r.origin.x = Coord(x)
            c.drawRect(r)
    if gridSize.height > 0:
        r.origin.x = 0
        r.size.width = bounds.width
        r.size.height = 1
        for y in countup(0, int(bounds.height), int(gridSize.height)):
            r.origin.y = Coord(y)
            c.drawRect(r)
