import view
export view

import view_event_handling
import event
import context
import clip_view

import logging
import app

import intsets

type SelectionMode = enum
    smNone
    smSingleSelection
    smMultipleSelection

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

method isCell(c: View): TableViewCell = nil
method isCell(c: TableViewCell): TableViewCell = c

type TableView* = ref object of View
    numberOfRows*: proc (): int
    createCell*: proc(): TableViewCell
    configureCell*: proc (cell: TableViewCell)
    heightOfRow*: proc (row: int): Coord
    onSelectionChange*: proc()

    defaultRowHeight*: Coord
    visibleRect: Rect
    selectionMode*: SelectionMode
    selectedRows*: IntSet

proc newTableView*(r: Rect): TableView =
    result.new()
    result.init(r)

method init*(v: TableView, r: Rect) =
    procCall v.View.init(r)
    v.defaultRowHeight = 30
    v.backgroundColor = newGrayColor(0.89)
    v.selectionMode = smSingleSelection
    v.selectedRows = initIntSet()

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

proc getRowsAtHeights(v: TableView, heights: openarray[Coord], rows: var openarray[int], startRow : int = 0, startCoord : Coord = 0) =
    let rowsCount = v.numberOfRows()
    if v.heightOfRow.isNil:
        for i in 0 .. < rows.len:
            rows[i] = int(heights[i] / v.defaultRowHeight)
            if rows[i] >= rowsCount:
                rows[i] = -1
                break
    else:
        # startCoord is topY of startRow
        var height = startCoord
        var j = 0
        rows[j] = -1
        for i in startRow .. < rowsCount:
            if j > heights.len:
                break
            height += v.heightOfRowUsingDelegate(i)
            if heights[j] < height:
                rows[j] = i
                inc j
                rows[j] = -1


proc reloadData*(v: TableView) =
    let rowCount = v.numberOfRows()
    var desiredSize = v.frame.size
    desiredSize.height = v.requiredTotalHeight(rowCount)
    if not v.superview.isNil:
        v.superview.subviewDidChangeDesiredSize(v, desiredSize)
    v.setNeedsDisplay()

proc containsFirstResponder(cell: TableViewCell): bool =
    let w = cell.window
    if not w.isNil:
        let fr = w.firstResponder
        if not fr.isNil:
            result = fr.isDescendantOf(cell)

proc topCoordOfRow(v: TableView, row: int): Coord {.inline.} =
    if v.heightOfRow.isNil:
        result = row.Coord * v.defaultRowHeight
    else:
        for i in 0 .. < row:
            result += v.heightOfRowUsingDelegate(i)

proc dequeueReusableCell(v: TableView, cells: var seq[TableViewCell], row: int, top: Coord): TableViewCell =
    var needToAdd = false
    if cells.len > 0:
        result = cells[0]
        cells.del(0)
    else:
        needToAdd = true
        result = v.createCell()

    result.setFrame(newRect(0, top, v.bounds.width, v.requiredHeightForRow(row)))
    result.row = row
    v.configureCell(result)
    if needToAdd:
        v.addSubview(result)

proc updateCellsInVisibleRect(v: TableView) =
    let clipView = v.enclosingClipView()
    let visibleRect = if clipView.isNil: v.bounds else: clipView.bounds
    if visibleRect != v.visibleRect:
        v.visibleRect = visibleRect

        var visibleRowsRange : array[2, int]

        assert(visibleRect.minY >= 0)

        v.getRowsAtHeights([visibleRect.minY, visibleRect.maxY], visibleRowsRange)

        let minVisibleRow = visibleRowsRange[0]
        var maxVisibleRow = visibleRowsRange[1]

        if maxVisibleRow < 0:
            maxVisibleRow = v.numberOfRows() - 1

        var reusableCells = newSeq[TableViewCell]()
        var visibleCells = newSeq[TableViewCell](maxVisibleRow - minVisibleRow + 1)

        # 1. Collect cells that are not within visible rect to reusable cells
        for sv in v.subviews:
            let cell = sv.isCell()
            if not cell.isNil:
                if (cell.row < minVisibleRow or cell.row > maxVisibleRow):
                    # If cell contains first responder it should remain intact
                    if not cell.containsFirstResponder():
                        reusableCells.add(cell)
                else:
                    visibleCells[cell.row - minVisibleRow] = cell

        var y : Coord = 0
        var cell = visibleCells[0]
        if cell.isNil:
            y = v.topCoordOfRow(minVisibleRow)
        else:
            y = cell.frame.minY

        # 2. Go through visible rows and create or reuse cells for rows with missing cells
        for i in minVisibleRow .. maxVisibleRow:
            var cell = visibleCells[i - minVisibleRow]
            if cell.isNil:
                cell = v.dequeueReusableCell(reusableCells, i, y)
                assert(not cell.isNil)
            y = cell.frame.maxY

        # 3. Remove the cells that were not reused
        for c in reusableCells:
            c.removeFromSuperview()

method draw*(v: TableView, r: Rect) =
    procCall v.View.draw(r)

    var needsDisplay = false
    if not v.window.isNil:
        needsDisplay = v.window.needsDisplay

    v.updateCellsInVisibleRect()

    if not v.window.isNil:
        v.window.needsDisplay = needsDisplay

method onMouseDown(b: TableView, e: var Event): bool =
    if b.selectionMode == smSingleSelection:
        var rows : array[1, int]
        b.getRowsAtHeights([e.localPosition.y], rows)
        if rows[0] != -1:
            mainApplication().pushEventFilter do(e: var Event, c: var EventFilterControl) -> bool:
                result = true
                if e.isButtonUpEvent():
                    b.selectedRows = initIntSet()
                    b.selectedRows.incl(rows[0])
                    if not b.onSelectionChange.isNil:
                        b.onSelectionChange()
                    c = efcBreak
                elif e.isMouseMoveEvent():
                    c = efcBreak

proc isRowSelected(t: TableView, row: int): bool = t.selectedRows.contains(row)

method draw(c: TableViewCell, r: Rect) =
    let tb = TableView c.superview
    if not tb.isNil:
        if tb.isRowSelected(c.row):
            let ctx = currentContext()
            ctx.fillColor = newColor(0, 0, 1)
            ctx.drawRect(c.bounds)
    procCall c.View.draw(r)
