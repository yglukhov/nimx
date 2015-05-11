import view
export view

import view_event_handling
import event
import context

import logging

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
    activeRow: int

proc newTableView*(r: Rect): TableView =
    result.new()
    result.init(r)

method init*(v: TableView, r: Rect) =
    procCall v.View.init(r)
    v.defaultRowHeight = 30
    v.activeRow = -1
    v.backgroundColor = newGrayColor(0.89)

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

#proc performActionInContextOfRow


method draw*(v: TableView, r: Rect) =
    procCall v.View.draw(r)

    let rowsCount = v.numberOfRows()
    var curY : Coord = 0
    var cellOrigin = zeroPoint
    var cellSize = newSize(v.bounds.width, 0)

    var cells = newSeq[TableViewCell]()
    let c = currentContext()

    let needsDisplay = v.window.needsDisplay

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
        if i mod 2 == 0:
            c.fillColor = newGrayColor(0.85)
            c.drawRect(cell.frame)

        cell.drawWithinSuperview()

    for c in cells:
        c.removeFromSuperview()
    v.window.needsDisplay = needsDisplay

proc rowAtPoint(v: TableView, p: Point): int =
    let rowsCount = v.numberOfRows()
    if v.heightOfRow.isNil:
        result = int(p.y / v.defaultRowHeight)
        if result >= rowsCount: result = -1
    else:
        var height : Coord
        result = -1
        for i in 0 .. < rowsCount:
            height += v.heightOfRowUsingDelegate(i)
            if p.y < height:
                return i

method handleMouseEvent*(v: TableView, e: var Event): bool =
    let row = v.rowAtPoint(e.localPosition)
    let localPosition = e.localPosition
    if row >= 0:
        let cell = v.cellForRow(row)
        e.localPosition = localPosition - cell.frame.origin + cell.bounds.origin
        result = cell.recursiveHandleMouseEvent(e)
    if not result:
        e.localPosition = localPosition
        result = procCall v.View.handleMouseEvent(e)

