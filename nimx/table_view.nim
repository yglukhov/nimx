import view
export view

import view_event_handling
import view_event_handling_new
import event
import context
import clip_view

import table_view_cell
export table_view_cell

import system_logger
import app

import intsets

type SelectionMode = enum
    smNone
    smSingleSelection
    smMultipleSelection

type SelectionKind* {.pure.} = enum
    Nothing = 0
    Row
    Column

type TableView* = ref object of View
    numberOfColumns*: int
    numberOfRows*: proc (): int
    mCreateCell: proc(c: int): TableViewCell
    configureCell*: proc (cell: TableViewCell)
    heightOfRow*: proc (row: int): Coord
    onSelectionChange*: proc()

    defaultRowHeight*: Coord
    defaultColWidth*: Coord
    visibleRect: Rect
    selectionMode*: SelectionMode
    selectedRows*: IntSet

    rows : array[1, int]
    initiallyClickedRow: int

proc `createCell=`*(v: TableView, p: proc(): TableViewCell) =
  v.mCreateCell = proc(c: int): TableViewCell =
    p()

proc `createCell=`*(v: TableView, p: proc(c: int): TableViewCell) =
  v.mCreateCell = p

proc newTableView*(r: Rect): TableView =
    result.new()
    result.init(r)

method init*(v: TableView, r: Rect) =
    procCall v.View.init(r)
    v.numberOfColumns = 1
    v.defaultRowHeight = 30
    v.defaultColWidth = 50
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
    v.visibleRect = zeroRect
    v.setNeedsDisplay()

proc containsFirstResponder(cell: View): bool =
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

type TableRow = ref object of View

proc dequeueReusableCell(v: TableView, cells: var seq[TableRow], row: int, top: Coord): TableRow =
    var needToAdd = false
    if cells.len > 0:
        result = cells[0]
        cells.del(0)
    else:
        needToAdd = true
        result = TableRow.new(newRect(0, 0, if v.numberOfColumns == 1: v.bounds.width else: (v.numberOfColumns.Coord * v.defaultColWidth).Coord, v.defaultRowHeight))
        let h = v.requiredHeightForRow(row)
        result.setFrame(newRect(0, top, v.bounds.width, h))
        for i in 0..< v.numberOfColumns:
            let c = v.mCreateCell(i)
            c.row = row
            let width = if v.numberOfColumns == 1:
                v.bounds.width
              else:
                v.defaultColWidth
            c.setFrame(newRect(width * i.Coord, 0, width, h))
            result.addSubview(c)

#    result.setFrame(newRect(0, top, v.bounds.width, v.requiredHeightForRow(row)))
#    result.row = row
#    result.col = col
    for i, s in result.subviews:
        TableViewCell(s).selected = v.selectedRows.contains(row)
        TableViewCell(s).col = i
        v.configureCell(TableViewCell(s))
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

        var reusableCells = newSeq[TableRow]()
        var visibleCells = newSeq[TableRow](maxVisibleRow - minVisibleRow + 1)

        # 1. Collect cells that are not within visible rect to reusable cells
        for sv in v.subviews:
            let cell = TableRow(sv)
            if not cell.isNil:
                let cr = TableViewCell(cell.subviews[0]).row
                if (cr < minVisibleRow or cr > maxVisibleRow):
                    # If cell contains first responder it should remain intact
                    if not cell.containsFirstResponder():
                        reusableCells.add(cell)
                else:
                    visibleCells[cr - minVisibleRow] = cell

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
            else:
                for c in cell.subviews:
                    v.configureCell(TableViewCell(c))
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

proc isRowSelected*(t: TableView, row: int): bool = t.selectedRows.contains(row)

proc updateSelectedCells*(t: TableView) {.inline.} =
    for i, s in t.subviews:
        for c in s.subviews:
            TableViewCell(c).selected = t.isRowSelected(i)

proc selectRow*(t: TableView, row: int) =
    t.selectedRows = initIntSet()
    t.selectedRows.incl(row)
    t.updateSelectedCells()
    if not t.onSelectionChange.isNil:
        t.onSelectionChange()
    t.setNeedsDisplay()

method onMouseDown(b: TableView, e: var Event): bool =
    if b.selectionMode == smSingleSelection:
        var rows : array[1, int]
        let initialPos = e.localPosition
        b.getRowsAtHeights([initialPos.y], rows)
        if rows[0] != -1:
            let initiallyClickedRow = rows[0]
            mainApplication().pushEventFilter do(e: var Event, c: var EventFilterControl) -> bool:
                if e.isPointingEvent():
                    result = true
                    if e.isButtonUpEvent():
                        b.selectRow(rows[0])
                        c = efcBreak
                    elif e.isMouseMoveEvent():
                        e.localPosition = b.convertPointFromWindow(e.position)
                        var newRows: array[1, int]
                        b.getRowsAtHeights([e.localPosition.y], newRows)
                        if newRows[0] != initiallyClickedRow:
                            c = efcBreak

method onTouchEv(b: TableView, e: var Event): bool =
    result = true
    case e.buttonState
        of bsDown:
            if b.selectionMode == smSingleSelection:
                let initialPos = e.localPosition
                b.rows[0] = -1
                b.getRowsAtHeights([initialPos.y], b.rows)
                if b.rows[0] != -1:
                    b.initiallyClickedRow = b.rows[0]
        of bsUnknown:
            e.localPosition = b.convertPointFromWindow(e.position)
            var newRows: array[1, int]
            b.getRowsAtHeights([e.localPosition.y], newRows)
            if newRows[0] != b.initiallyClickedRow:
                result = false
        of bsUp:
            if b.rows[0] != -1:
                b.selectRow(b.rows[0])
                result = false
