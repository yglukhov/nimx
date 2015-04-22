
import view
export view

import view_event_handling
import event

type TableViewCell* = ref object of View

proc newTableViewCell*(r: Rect): TableViewCell =
    result.new()
    result.init(r)

proc newTableViewCell*(s: Size): TableViewCell =
    newTableViewCell(newRect(zeroPoint, s))

proc newTableViewCell*(v: View): TableViewCell =
    result = newTableViewCell(v.frame.size)
    v.autoresizingMask = { afFlexibleWidth, afFlexibleHeight }
    result.addSubview(v)

type TableView* = ref object of View
    numberOfRows*: proc (): int
    cellForRow*: proc (row: int): TableViewCell
    heightOfRow*: proc (row: int): Coord

    defaultRowHeight*: Coord

proc newTableView*(r: Rect): TableView =
    result.new()
    result.init(r)

method init*(v: TableView, r: Rect) =
    procCall v.View.init(r)
    v.defaultRowHeight = 30


proc heightOfRowUsingDelegate(v: TableView, row: int): Coord {.inline.} =
    result = v.heightOfRow(row)
    if result < 0:
        result = v.defaultRowHeight

proc requiredTotalHeight(v: TableView, rowCount: int): Coord {.inline.} =
    if v.heightOfRow.isNil:
        result = v.defaultRowHeight * rowCount.Coord
    else:
        for i in 0 .. < rowCount:
            result += v.heightOfRowUsingDelegate(i)

proc requiredHeightForRow(v: TableView, row: int): Coord {.inline.} =
    if v.heightOfRow.isNil:
        result = v.defaultRowHeight
    else:
        result = v.heightOfRowUsingDelegate(row)

proc reloadData*(v: TableView) =
    let rowCount = v.numberOfRows()
    var desiredSize = v.frame.size
    desiredSize.height = v.requiredTotalHeight(rowCount)
    if not v.superview.isNil:
        v.superview.subviewDidChangeDesiredSize(v, desiredSize)

method draw*(v: TableView, r: Rect) =
    let rowsCount = v.numberOfRows()
    var curY : Coord = 0
    var cellOrigin = zeroPoint
    var cellSize = newSize(v.bounds.width, 0)

    var cells = newSeq[TableViewCell]()

    for i in 0 .. < rowsCount:
        let cell = v.cellForRow(i)
        let cellHeight = v.requiredHeightForRow(i)

        if cell.superview != v:
            v.addSubview(cell)
            cells.add(cell)

        cellSize.height = cellHeight
        cell.setFrameOrigin(cellOrigin)
        cell.setFrameSize(cellSize)
        cellOrigin.y += cellHeight
        cell.drawWithinSuperview()

    for c in cells:
        c.removeFromSuperview()

proc rowAtPoint(v: TableView, p: Point): int =
    let rowsCount = v.numberOfRows()
    if v.heightOfRow.isNil:
        result = int(p.y / v.defaultRowHeight)
        if result >= rowsCount: result = -1
    else:
        var height : Coord
        for i in 0 .. < rowsCount:
            height += v.heightOfRowUsingDelegate(i)
            if p.y < height:
                return i
    return -1

discard """
method handleMouseEvent*(v: TableView, e: var Event): bool =
    let row = v.rowAtPoint(e.localPosition)
    if row >= 0:
        let cell = v.cellForRow(row)
    

    if e.isButtonDownEvent():
        result = v.onMouseDown(e)
    elif e.isButtonUpEvent():
        result = v.onMouseUp(e)
    elif e.kind == etScroll:
        result = v.onScroll(e)
"""

