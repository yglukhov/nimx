import view, view_event_handling, table_view_cell, scroll_view, layout_vars,
       pasteboard/pasteboard_item, keyboard

import intsets
import kiwi

export view, table_view_cell

type
  SelectionMode* = enum
    smNone
    smSingleSelection
    smMultipleSelection

  DragOperation* = enum
    none
    move
    copy

  TableView* = ref object of View
    numberOfColumns*: int
    numberOfRows*: proc (): int {.gcsafe.}
    mCreateCell: proc(column: int): TableViewCell {.gcsafe.}
    mConfigureCell: proc (cell: TableViewCell) {.gcsafe.}
    heightOfRow*: proc (row: int): Coord {.gcsafe.}
    onSelectionChange*: proc() {.gcsafe.}

    defaultRowHeight*: Coord
    defaultColWidth*: Coord
    visibleRect: Rect
    selectionMode*: SelectionMode
    selectedRows*: IntSet

    initiallyClickedRow: int
    constraints: seq[Constraint]

    # Drag source
    mOnDragStarted: proc(rows: IntSet): PasteboardItem {.gcsafe.}
    mOnDragComplete: proc(rows: IntSet, op: DragOperation) {.gcsafe.}

    # Drag destination
    mAcceptDrop: proc(i: PasteboardItem, atRow: int, inside: bool): DragOperation {.gcsafe.}
    mOnDrop: proc(i: PasteboardItem, atRow: int, inside: bool) {.gcsafe.}

proc `createCell=`*(v: TableView, p: proc(): TableViewCell {.gcsafe.}) =
  v.mCreateCell = proc(c: int): TableViewCell =
    p()

proc `createCell=`*(v: TableView, p: proc(column: int): TableViewCell {.gcsafe.}) =
  v.mCreateCell = p

proc `configureCell=`*(v: TableView, p: proc (cell: TableViewCell) {.gcsafe.}) =
  v.mConfigureCell = p

proc rebuildConstraints(v: TableView) {.gcsafe.}

method init*(v: TableView) =
  procCall v.View.init()
  v.numberOfColumns = 1
  v.defaultRowHeight = 30
  v.defaultColWidth = 50
  v.backgroundColor = newGrayColor(0.89)
  v.selectionMode = smSingleSelection
  v.selectedRows = initIntSet()

  v.rebuildConstraints()

proc heightOfRowUsingDelegate(v: TableView, row: int): Coord {.inline.} =
  result = v.heightOfRow(row)
  if result < 0:
    result = v.defaultRowHeight

proc requiredTotalHeight(v: TableView, rowCount: int): Coord {.inline.} =
  if v.heightOfRow.isNil:
    result = v.defaultRowHeight * rowCount.Coord
  else:
    for i in 0 ..< rowCount:
      result += v.heightOfRowUsingDelegate(i)

proc requiredHeightForRow(v: TableView, row: int): Coord {.inline.} =
  if v.heightOfRow.isNil:
    result = v.defaultRowHeight
  else:
    result = v.heightOfRowUsingDelegate(row)

proc getRowsAtHeights(v: TableView, heights: openarray[Coord], rows: var openarray[int], startRow : int = 0, startCoord : Coord = 0) =
  let rowsCount = v.numberOfRows()
  if v.heightOfRow.isNil:
    for i in 0 ..< rows.len:
      rows[i] = int((startCoord + heights[i]) / v.defaultRowHeight)
      if rows[i] >= rowsCount:
        rows[i] = -1
        break
  else:
    # startCoord is topY of startRow
    var height = startCoord
    var j = 0
    rows[j] = -1
    for i in startRow ..< rowsCount:
      if j >= heights.len:
        break
      height += v.heightOfRowUsingDelegate(i)
      if heights[j] < height:
        rows[j] = i
        inc j
        if j < rows.len:
          rows[j] = -1

proc rebuildConstraints(v: TableView) =
  v.removeConstraints(v.constraints)
  v.constraints.setLen(0)

  if v.numberOfRows.isNil:
    v.constraints.add(v.layout.vars.height == 0)
  else:
    let rowCount = v.numberOfRows()
    let height = v.requiredTotalHeight(rowCount)
    v.constraints.add(v.layout.vars.height == height)

  v.addConstraints(v.constraints)

proc updateCellsInVisibleRect(v: TableView)

proc visibleRect(v: View): Rect = # TODO: This can be more generic. Move to view.nim
  let s = v.superview
  if s.isNil: return zeroRect
  result = v.bounds
  if s of ScrollView:
    let o = v.frame.origin
    let sb = s.bounds.size
    if o.x < 0:
      result.origin.x += -o.x
      result.size.width += o.x
    if o.y < 0:
      result.origin.y += -o.y
      result.size.height += o.y

    if o.x + result.width > sb.width: result.size.width = sb.width - o.x
    if o.y + result.height > sb.height: result.size.height = sb.height - o.y
  else:
    result = v.bounds

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
    for i in 0 ..< row:
      result += v.heightOfRowUsingDelegate(i)

type TableRow = ref object of View
  topConstraint, heightConstraint: Constraint

proc configureRow(r: TableRow, top, height: Coord) {.inline.} =
  if not r.topConstraint.isNil:
    r.removeConstraint(r.topConstraint)
  r.topConstraint = r.layout.vars.top == superPHS.top + top
  r.addConstraint(r.topConstraint)
  if not r.heightConstraint.isNil:
    r.removeConstraint(r.heightConstraint)
  r.heightConstraint = r.layout.vars.height == height
  r.addConstraint(r.heightConstraint)

proc createRow(v: TableView): TableRow =
  result = TableRow.new()
  #result.addConstraint(result.layout.vars.height == height)
  result.addConstraint(result.layout.vars.leading == superPHS.leading)
  result.addConstraint(result.layout.vars.trailing == superPHS.trailing)
  for i in 0 ..< v.numberOfColumns:
    let c = v.mCreateCell(i)
    c.col = i
    c.addConstraint(c.layout.vars.top == superPHS.top)
    c.addConstraint(c.layout.vars.bottom == superPHS.bottom)

    if i == 0:
      c.addConstraint(c.layout.vars.leading == superPHS.leading)
    else:
      c.addConstraint(c.layout.vars.leading == prevPHS.leading)

    result.addSubview(c)

  let lastCell = result.subviews[^1]
  lastCell.addConstraint(lastCell.layout.vars.trailing == superPHS.trailing)

proc dequeueReusableRow(v: TableView, cells: var seq[TableRow], row: int, top, height: Coord): TableRow =
  var needToAdd = false
  if cells.len > 0:
    result = cells[0]
    cells.del(0)
  else:
    needToAdd = true
    result = v.createRow()

  let rowSelected = v.selectedRows.contains(row)
  for s in result.subviews:
    let cell = TableViewCell(s)
    cell.selected = rowSelected
    cell.row = row
    v.mConfigureCell(cell)

  result.configureRow(top, height)

  if needToAdd:
    v.addSubview(result)

proc updateCellsInRect(v: TableView, vr: Rect) =
  var visibleRowsRange : array[2, int]

  assert(vr.minY >= 0)

  v.getRowsAtHeights([vr.minY, vr.maxY], visibleRowsRange)

  let minVisibleRow = visibleRowsRange[0]
  var maxVisibleRow = visibleRowsRange[1]

  if maxVisibleRow < 0:
    maxVisibleRow = v.numberOfRows() - 1

  var reusableRows = newSeq[TableRow]()
  var visibleRows = newSeq[TableRow](maxVisibleRow - minVisibleRow + 1)

  # 1. Collect cells that are not within visible rect to reusable cells
  for sv in v.subviews:
    let cell = TableRow(sv)
    let cr = TableViewCell(cell.subviews[0]).row
    if (cr < minVisibleRow or cr > maxVisibleRow) or minVisibleRow == -1:
      # If cell contains first responder it should remain intact
      if not cell.containsFirstResponder():
        reusableRows.add(cell)
    else:
      visibleRows[cr - minVisibleRow] = cell

  if minVisibleRow != -1:
    var y : Coord = 0
    var cell = visibleRows[0]
    if cell.isNil:
      y = v.topCoordOfRow(minVisibleRow)
    else:
      y = cell.frame.minY

    # 2. Go through visible rows and create or reuse cells for rows with missing cells
    for i in minVisibleRow .. maxVisibleRow:
      var cell = visibleRows[i - minVisibleRow]
      let h = v.requiredHeightForRow(i)

      if cell.isNil:
        cell = v.dequeueReusableRow(reusableRows, i, y, h)
        assert(not cell.isNil)
      else:
        for c in cell.subviews:
          v.mConfigureCell(TableViewCell(c))
      y += h

  # 3. Remove the cells that were not reused
  for c in reusableRows:
    c.removeFromSuperview()

proc calculateVisibleRect(v: TableView): Rect =
  visibleRect(v)

proc updateCellsInVisibleRect(v: TableView) =
  let vr = v.calculateVisibleRect()
  if vr != v.visibleRect:
    v.visibleRect = vr
    v.updateCellsInRect(vr)

proc reloadData*(v: TableView) =
  v.rebuildConstraints()
  v.updateCellsInRect(v.calculateVisibleRect())
  v.setNeedsDisplay()

method updateLayout*(v: TableView) =
  v.updateCellsInVisibleRect()

proc isRowSelected*(t: TableView, row: int): bool = t.selectedRows.contains(row)

proc updateSelectedCells(t: TableView) {.inline.} =
  # TODO: This can be more efficient.
  for r in t.subviews:
    let isSelected = t.isRowSelected(TableViewCell(r.subviews[0]).row)
    for c in r.subviews:
      let cell = TableViewCell(c)
      if cell.selected != isSelected:
        cell.selected = isSelected
        t.mConfigureCell(cell)

proc setRowsSelected(t: TableView, rows: Slice[int], selected: bool) =
  if selected:
    for i in rows: t.selectedRows.incl(i)
  else:
    for i in rows: t.selectedRows.excl(i)
  t.updateSelectedCells()
  if not t.onSelectionChange.isNil:
    t.onSelectionChange()
  t.setNeedsDisplay()

proc setRowSelected*(t: TableView, row: int, selected: bool) =
  t.setRowsSelected(row .. row, selected)

proc toggleSelectedRow(t: TableView, row: int) =
  t.setRowSelected(row, not t.isRowSelected(row))

proc selectRow*(t: TableView, row: int) =
  t.selectedRows = initIntSet()
  t.setRowSelected(row, true)

proc clearSelection*(t: TableView) =
  t.selectedRows = initIntSet()
  t.setRowsSelected(0 .. -1, false)

proc selectRows(t: TableView, rows: Slice[int]) =
  t.setRowsSelected(rows, true)

proc handleRowSelection(t: TableView, row: int, e: var Event): bool =
  result = true
  # is multiseelct modifier key pressed (cmd on macos, else ctrl)
  let msKey = e.modifiers.anyOsModifier()
  if t.selectionMode == smSingleSelection:
    t.selectRow(row)
    result = false
  elif t.selectionMode == smMultipleSelection:
    if msKey:
      t.toggleSelectedRow(row)
      result = false
    elif e.modifiers.anyShift():
      # Shift-select. Currently we implement range select only if
      # clicked the clicked has no surrounding selected rows from both sides
      # Case 1. If there are no selected rows - select this row
      if t.selectedRows.len == 0:
        t.selectRow(row)
      elif t.isRowSelected(row):
        t.toggleSelectedRow(row)
      else:
        # Find selection below
        var selectionBelow = -1
        for i in countdown(row - 1, 0):
          if i in t.selectedRows:
            selectionBelow = i
            break
        # Find selection above
        var selectionAbove = -1
        for i in row + 1 .. t.numberOfRows():
          if i in t.selectedRows:
            selectionAbove = i
            break
        if selectionAbove != -1 and selectionBelow != -1:
          t.toggleSelectedRow(row)
        elif selectionAbove != -1:
          t.selectRows(row ..< selectionAbove)
        else:
          t.selectRows(selectionBelow + 1 .. row)

      result = false
    else:
      t.selectRow(row)
      result = false

method onTouchEv*(b: TableView, e: var Event): bool =
  result = true
  case e.buttonState
    of bsDown:
      if b.selectionMode in {smSingleSelection, smMultipleSelection}:
        let initialPos = e.localPosition
        var rows = [-1]
        b.getRowsAtHeights([initialPos.y], rows)
        b.initiallyClickedRow = rows[0]
    of bsUnknown:
      e.localPosition = b.convertPointFromWindow(e.position)
      var newRows: array[1, int]
      b.getRowsAtHeights([e.localPosition.y], newRows)
      if newRows[0] != b.initiallyClickedRow:
        result = false
    of bsUp:
      if b.initiallyClickedRow != -1:
        result = b.handleRowSelection(b.initiallyClickedRow, e)
