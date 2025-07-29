import view
export view
import context
import types

type TableViewCell* = ref object of View
  row*, col*: int
  selected*: bool

proc newTableViewCell*(): TableViewCell =
  result.new()
  result.init()

proc newTableViewCell*(v: View): TableViewCell =
  result = newTableViewCell()
  result.addSubview(v)

method selectionColor*(c: TableViewCell): Color {.base, gcsafe.} =
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
