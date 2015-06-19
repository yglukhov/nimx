import view
export view
import context

type TableViewCell* = ref object of View
    row*: int
    selected*: bool

proc newTableViewCell*(r: Rect): TableViewCell =
    result.new()
    result.init(r)

proc newTableViewCell*(s: Size): TableViewCell =
    newTableViewCell(newRect(zeroPoint, s))

proc newTableViewCell*(v: View): TableViewCell =
    result = newTableViewCell(v.frame.size)
    v.autoresizingMask = { afFlexibleWidth, afFlexibleHeight }
    result.addSubview(v)

method isTableViewCell*(c: View): TableViewCell = nil
method isTableViewCell*(c: TableViewCell): TableViewCell = c

proc enclosingTableViewCell*(v: View): TableViewCell =
    var iv = v
    while not iv.isNil:
        let cell = iv.isTableViewCell()
        if not cell.isNil: return cell
        iv = iv.superview

method draw(c: TableViewCell, r: Rect) =
    if c.selected:
        let ctx = currentContext()
        ctx.fillColor = newColor(0, 0, 1)
        ctx.strokeWidth = 0
        ctx.drawRect(c.bounds)
    procCall c.View.draw(r)
