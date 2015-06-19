import view
export view

type TableViewCell* = ref object of View
    row*: int

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
        if not cell.isNil:
            return cell
