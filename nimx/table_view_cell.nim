import view
export view
import context
import types

type TableViewCell* = ref object of View
    row*, col*: int
    selected*: bool

proc newTableViewCell*(): TableViewCell =
    result.new()
    result.init(zeroRect)

proc newTableViewCell*(r: Rect): TableViewCell =
    result.new()
    result.init(r)

proc newTableViewCell*(s: Size): TableViewCell =
    newTableViewCell(newRect(zeroPoint, s))

proc newTableViewCell*(v: View): TableViewCell =
    result = newTableViewCell(v.frame.size)
    v.autoresizingMask = { afFlexibleWidth, afFlexibleHeight }
    result.addSubview(v)

method selectionColor*(c: TableViewCell): Color {.base.} =
    return newColor(0.0, 0.0, 1.0)

proc enclosingTableViewCell*(v: View): TableViewCell {.inline.} =
    v.enclosingViewOfType(TableViewCell)

method draw*(c: TableViewCell, r: Rect) =
    if c.selected:
        let ctx = currentContext()
        ctx.fillColor = c.selectionColor()
        ctx.strokeWidth = 0
        ctx.drawRect(c.bounds)
    procCall c.View.draw(r)

registerClass(TableViewCell)
