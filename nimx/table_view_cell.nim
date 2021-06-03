import view
export view
import context
import types

type TableViewCell* = ref object of View
    row*, col*: int
    selected*: bool

proc newTableViewCell*(gfx: GraphicsContext): TableViewCell =
    result.new()
    result.init(gfx, zeroRect)

proc newTableViewCell*(gfx: GraphicsContext, r: Rect): TableViewCell =
    result.new()
    result.init(gfx, r)

proc newTableViewCell*(gfx: GraphicsContext, s: Size): TableViewCell =
    newTableViewCell(gfx, newRect(zeroPoint, s))

proc newTableViewCell*(gfx: GraphicsContext, v: View): TableViewCell =
    result = newTableViewCell(gfx, v.frame.size)
    v.autoresizingMask = { afFlexibleWidth, afFlexibleHeight }
    result.addSubview(v)

method selectionColor*(c: TableViewCell): Color {.base.} =
    return newColor(0.0, 0.0, 1.0)

proc enclosingTableViewCell*(v: View): TableViewCell {.inline.} =
    v.enclosingViewOfType(TableViewCell)

method draw*(c: TableViewCell, r: Rect) =
    template gfx: untyped = c.gfx
    if c.selected:
        gfx.fillColor = c.selectionColor()
        gfx.strokeWidth = 0
        gfx.drawRect(c.bounds)
    procCall c.View.draw(r)

registerClass(TableViewCell)
