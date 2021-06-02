import view
export view
import context
import types

type TableViewCell* = ref object of View
    row*, col*: int
    selected*: bool

proc newTableViewCell*(w: Window): TableViewCell =
    result.new()
    result.init(w, zeroRect)

proc newTableViewCell*(w: Window, r: Rect): TableViewCell =
    result.new()
    result.init(w, r)

proc newTableViewCell*(w: Window, s: Size): TableViewCell =
    newTableViewCell(w, newRect(zeroPoint, s))

proc newTableViewCell*(w: Window, v: View): TableViewCell =
    result = newTableViewCell(w, v.frame.size)
    v.autoresizingMask = { afFlexibleWidth, afFlexibleHeight }
    result.addSubview(v)

method selectionColor*(c: TableViewCell): Color {.base.} =
    return newColor(0.0, 0.0, 1.0)

proc enclosingTableViewCell*(v: View): TableViewCell {.inline.} =
    v.enclosingViewOfType(TableViewCell)

method draw*(c: TableViewCell, r: Rect) =
    template gfxCtx: untyped = c.window.gfxCtx
    if c.selected:
        gfxCtx.fillColor = c.selectionColor()
        gfxCtx.strokeWidth = 0
        gfxCtx.drawRect(c.bounds)
    procCall c.View.draw(r)

registerClass(TableViewCell)
