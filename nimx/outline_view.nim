import nimx/[view, context, types, table_view, view_event_handling, scroll_view, layout_vars, layout]

import scroll_view

import math
import variant
import kiwi

export TableViewCell

const offsetOutline = 6

type
    OutlineView* = ref object of TableView
        mOutlineViewDataSource: OutlineViewDatasourceBase
        mDataSource: OutlineViewDatasourceBase
        items: seq[ItemNode]
        rootItem: ItemNode
        outlineColumn: int # index of column where disclosure triangles appear
        selectedIndexPath*: IndexPath
        onDragAndDrop*: proc(fromIndexPath, toIndexPath: openarray[int]) {.gcsafe.}
        tempIndexPath: IndexPath
        draggedElemIndexPath: IndexPath # Initial index path of the element that is currently being dragged
        droppedElemIndexPath: IndexPath # Initial index path of the element that is currently being dragged
        dropAfterItem: ItemNode
        dropInsideItem: ItemNode
        dragStartLocation: Point

    IndexPath* = seq[int]

    OutlineViewDatasourceBase = ref object of RootObj
        typeId: TypeId
        mConfigureCellBase: proc(d: OutlineViewDatasourceBase, c: TableViewCell, i: ItemNode) {.nimcall, gcsafe.}
        mReloadDataForNode: proc(d: OutlineViewDatasourceBase, item: ItemNode, ip: var IndexPath) {.nimcall, gcsafe.}

    OutlineViewDatasource[T] = ref object of OutlineViewDatasourceBase
        mNumberOfChildren: proc(i: T, ip: IndexPath): int {.gcsafe.}
        mRootItem: proc(): T {.gcsafe.}
        mChildOfItem: proc(i: T, ip: IndexPath): T {.gcsafe.}
        mConfigureCell: proc(i: T, c: TableViewCell) {.gcsafe.}
        mDisplayFilter: proc(i: T): bool {.gcsafe.}

    ItemNode = ref object
        expanded: bool
        expandable: bool
        filtered: bool
        children: seq[ItemNode]
        item: Variant
        # cell: TableViewCell
        nestLevel: int

    OutlineCell = ref object of TableViewCell
        offsetConstraint: Constraint
        mItem: ItemNode
        outlineView: OutlineView

proc offsetInPixels(c: OutlineCell): float32 =
    float32(offsetOutline + c.mItem.nestLevel * offsetOutline * 2 + 6)

proc `item=`(c: OutlineCell, item: ItemNode) =
    if c.mItem != item:
        let oldItem = c.mItem
        let oldNestLevel = if oldItem.isNil: 0 else: oldItem.nestLevel
        c.mItem = item

        if c.offsetConstraint.isNil or item.nestLevel != oldNestLevel:
            if not c.offsetConstraint.isNil:
                c.removeConstraint(c.offsetConstraint)
            let tbvCell = c.subviews[0]
            c.offsetConstraint = tbvCell.layout.vars.leading == c.layout.vars.leading + c.offsetInPixels
            c.addConstraint(c.offsetConstraint)

proc disclosureTriangleRect(c: OutlineCell): Rect =
    let sz = c.bounds.height
    let o = c.offsetInPixels
    newRect(c.bounds.x + o - sz + 4, 0, sz, sz)

proc drawDisclosureTriangle(ctx: GraphicsContext, disclosed: bool, r: Rect) =
    ctx.drawTriangle(r, if disclosed: Coord(PI / 2.0) else: Coord(0))

method draw*(c: OutlineCell, r: Rect) =
    procCall c.TableViewCell.draw(r)
    let ctx = currentContext()
    if c.selected:
        ctx.fillColor = newColor(1, 1, 1)
    else:
        ctx.fillColor = newColor(0.1, 0.1, 0.1)
    ctx.drawDisclosureTriangle(c.mItem.expanded, c.disclosureTriangleRect)

proc reloadItemsForTableView(v: OutlineView) {.gcsafe.}

method onTouchEv*(v: OutlineCell, e: var Event): bool =
    result = procCall v.View.onTouchEv(e)
    if e.buttonState == bsUp:
        discard # TODO: ...
    elif e.buttonState == bsDown:
        let pos = e.localPosition
        if pos in v.disclosureTriangleRect:
            let it = v.mItem
            it.expanded = not it.expanded
            v.outlineView.reloadItemsForTableView()
            result = true

const rowHeight = 20.Coord

proc configureCellBase[T](v: OutlineViewDatasourceBase, cell: TableViewCell, n: ItemNode) =
    let v = cast[OutlineViewDatasource[T]](v)
    v.mConfigureCell(n.item.get(T), cell)

proc reloadDataForNode[T](v: OutlineViewDatasource[T], n: ItemNode, indexPath: var IndexPath) =
    let childrenCount = v.mNumberOfChildren(n.item.get(T), indexPath)
    n.children.setLen(childrenCount)

    let lastIndex = indexPath.len
    indexPath.add(0)

    if not v.mDisplayFilter.isNil:
        n.filtered = not v.mDisplayFilter(n.item.get(T))
    else:
        n.filtered = false

    for i in 0 ..< childrenCount:
        indexPath[lastIndex] = i
        if n.children[i].isNil:
            n.children[i] = ItemNode(expandable: true)

        n.children[i].nestLevel = lastIndex
        n.children[i].item = newVariant(v.mChildOfItem(n.item.get(T), indexPath))
        v.reloadDataForNode(n.children[i], indexPath)

        if not n.children[i].filtered:
            n.filtered = false

    indexPath.setLen(lastIndex)

proc reloadDataForNodeAux[T](v: OutlineViewDatasourceBase, n: ItemNode, ip: var IndexPath) =
    let v = cast[OutlineViewDatasource[T]](v)
    n.item = newVariant(v.mRootItem())
    reloadDataForNode(v, n, ip)

proc dataSource(v: OutlineView, T: typedesc): OutlineViewDatasource[T] =
    const tid = getTypeId(T)
    if v.mDataSource.isNil:
        result = OutlineViewDatasource[T](typeId: tid, mReloadDataForNode: reloadDataForNodeAux[T], mConfigureCellBase: configureCellBase[T])
        v.mDataSource = result

    else:
        assert(v.mDataSource.typeId == tid)
        result = cast[OutlineViewDatasource[T]](v.mDataSource)

proc `numberOfChildren=`*[T](v: OutlineView, cb: proc(i: T, ip: IndexPath): int {.gcsafe.}) =
    dataSource(v, T).mNumberOfChildren = cb

proc `rootItem=`*[T](v: OutlineView, cb: proc(): T {.gcsafe.}) =
    dataSource(v, T).mRootItem = cb

proc `childOfItem=`*[T](v: OutlineView, cb: proc(i: T, indexPath: IndexPath): T {.gcsafe.}) =
    dataSource(v, T).mChildOfItem = cb

proc `configureCell=`*[T](v: OutlineView, cb: proc(i: T, c: TableViewCell) {.gcsafe.}) =
    dataSource(v, T).mConfigureCell = cb

proc `createCell=`*(v: OutlineView, cb: proc(col: int): TableViewCell {.gcsafe.}) =
    v.TableView.createCell = proc(col: int): TableViewCell =
        let tbvCell = cb(col)
        tbvCell.col = col
        tbvCell.addConstraint(selfPHS.top == superPHS.top)
        tbvCell.addConstraint(selfPHS.bottom == superPHS.bottom)

        if col == v.outlineColumn:
            let oc = OutlineCell.new()
            oc.init(zeroRect)
            result = oc
            oc.makeLayout:
                col: col
                outlineView: v
                top == super
                bottom == super

            tbvCell.addConstraint(selfPHS.trailing == superPHS.trailing)
            result.addSubview(tbvCell)
        else:
            result = tbvCell

proc `createCell=`*(v: OutlineView, cb: proc(): TableViewCell {.gcsafe.}) =
    v.createCell = proc(col: int): TableViewCell =
        cb()

method init*(v: OutlineView, r: Rect) =
    procCall v.TableView.init(r)
    v.rootItem = ItemNode.new()
    v.rootItem.expandable = true
    v.rootItem.expanded = true
    v.numberOfRows = proc(): int =
        v.items.len

    v.configureCell = proc(cell: TableViewCell) {.gcsafe.}=
        var cell = cell
        let item = v.items[cell.row]
        if cell.col == v.outlineColumn:
            let oc = OutlineCell(cell)
            let tc = TableViewCell(cell.subviews[0])
            oc.item = item
            tc.row = oc.row
            tc.selected = oc.selected
            cell = tc
        v.mDataSource.mConfigureCellBase(v.mDataSource, cell, item)

template xOffsetForIndexPath(ip: IndexPath): Coord =
    Coord(offsetOutline + ip.len * offsetOutline * 2)

proc configureCellAux(v: OutlineView, c: TableViewCell, n: ItemNode) =
    v.mDataSource.mConfigureCellBase(v.mDataSource, c, n)

iterator nodesOnPath(v: OutlineView, indexPath: openarray[int]): ItemNode =
    var n = v.rootItem
    for i in indexPath:
        if i < n.children.len:
            n = n.children[i]
        yield n

proc nodeAtIndexPath(v: OutlineView, indexPath: openarray[int]): ItemNode =
    for n in v.nodesOnPath(indexPath):
        result = n

proc selectedNode(v: OutlineView): ItemNode =
    v.nodeAtIndexPath(v.selectedIndexPath)

proc getExposedRowsCount(node: ItemNode): int =
    result = 1
    if node.expanded:
        for child in node.children:
            if child.filtered: continue
            result += child.getExposedRowsCount()

proc getExposingRowNum(v: OutlineView, indexPath: IndexPath): int =
    result = -1
    var parentNode = v.rootItem
    for indexInPath in indexPath:
        result += 1
        for neighb in 0 ..< indexInPath:
            let ch = parentNode.children[neighb]
            if ch.filtered: continue
            result += ch.getExposedRowsCount
        parentNode = parentNode.children[indexInPath]

proc setRowExpanded*(v: OutlineView, expanded: bool, indexPath: openarray[int]) =
    v.nodeAtIndexPath(indexPath).expanded = expanded
    v.reloadItemsForTableView()

proc expandRow*(v: OutlineView, indexPath: openarray[int]) =
    v.setRowExpanded(true, indexPath)

proc collapseRow*(v: OutlineView, indexPath: openarray[int]) =
    v.setRowExpanded(false, indexPath)

proc itemAtIndexPath*(v: OutlineView, indexPath: openarray[int]): Variant =
    v.nodeAtIndexPath(indexPath).item

proc setBranchExpanded*(v: OutlineView, expanded: bool, indexPath: openarray[int]) =
    if expanded:
        for n in v.nodesOnPath(indexPath):
            n.expanded = true
        v.reloadItemsForTableView()
    else:
        v.setRowExpanded(false, indexPath)

proc expandBranch*(v: OutlineView, indexPath: openarray[int]) =
    v.setBranchExpanded(true, indexPath)

proc collapseBranch*(v: OutlineView, indexPath: openarray[int]) =
    v.setBranchExpanded(false, indexPath)

proc itemAtPos(v: OutlineView, n: ItemNode, p: Point, y: var Coord, indexPath: var IndexPath): ItemNode =
    y += rowHeight
    if p.y < y: return n
    if n.expanded and n.children.len != 0:
        let lastIndex = indexPath.len
        indexPath.add(0)
        for i, c in n.children:
            if c.filtered: continue
            indexPath[lastIndex] = i
            result = v.itemAtPos(c, p, y, indexPath)
            if not result.isNil: return
        indexPath.setLen(lastIndex)

proc itemAtPos(v: OutlineView, p: Point, indexPath: var IndexPath, y: var Coord): ItemNode =
    indexPath.setLen(1)
    for i, c in v.rootItem.children:
        indexPath[0] = i
        if c.filtered: continue
        result = v.itemAtPos(c, p, y, indexPath)
        if not result.isNil:
            y -= rowHeight
            break

proc selectedIndexPaths*(v: OutlineView, allowOverlap = false): seq[IndexPath] =
    assert(false, "Not implemented")

proc flattenItem(v: OutlineView, i: ItemNode) =
    for c in i.children:
        if not c.filtered:
            v.items.add(c)
            if c.expanded:
                v.flattenItem(c)

proc reloadItemsForTableView(v: OutlineView) =
    v.items.setLen(0)
    v.flattenItem(v.rootItem)
    procCall v.TableView.reloadData()

proc reloadData*(v: OutlineView) =
    v.tempIndexPath.setLen(0)
    v.mDataSource.mReloadDataForNode(v.mDataSource, v.rootItem, v.tempIndexPath)
    v.reloadItemsForTableView()

proc setDisplayFilter*[T](v: OutlineView, f: proc(item: T): bool)=
    dataSource(v, T).mDisplayFilter = f

template selectionChanged(v: OutlineView) =
    if not v.onSelectionChange.isNil: v.onSelectionChange()

proc scrollToSelection*(v: OutlineView) =
    let scrollView = v.enclosingViewOfType(ScrollView)
    if not scrollView.isNil:
        var targetRect = newRect(newPoint(0, v.getExposingRowNum(v.selectedIndexPath).Coord * rowHeight), newSize(1, rowHeight))
        scrollView.scrollToRect(targetRect)

proc selectItemAtIndexPath*(v: OutlineView, ip: seq[int], scroll: bool = true) =
    if ip.len > 1:
        v.expandBranch(ip[0..^2])
    v.selectedIndexPath = ip
    v.selectionChanged()
    if scroll:
        v.scrollToSelection()

proc isSubpathOfPath(subpath, path: openarray[int]): bool =
    if path.len >= subpath.len:
        var i = 0
        while i < subpath.len:
            if path[i] != subpath[i]: return
            inc i
        return true

method onTouchEv*(v: OutlineView, e: var Event): bool =
    result = procCall v.TableView.onTouchEv(e)

    # if e.buttonState == bsUp:
    #     let pos = e.localPosition
    #     var y = 0.Coord
    #     let i = v.itemAtPos(pos, v.tempIndexPath, y)

    #     if not v.touchTarget.isNil:
    #         if not i.isNil and i.cell.View != v.touchTarget:
    #             e.localPosition = i.cell.convertPointFromParent(pos)
    #         e.localPosition = v.touchTarget.convertPointFromParent(e.localPosition)
    #         if v.touchTarget.processTouchEvent(e):
    #             v.setNeedsDisplay()
    #             return true

    #     v.touchTarget = nil

    #     if not i.isNil:
    #         if pos.x < xOffsetForIndexPath(v.tempIndexPath) and i.expandable:
    #             i.expanded = not i.expanded
    #             v.checkViewSize()
    #         elif v.tempIndexPath != v.selectedIndexPath:
    #             v.selectedIndexPath = v.tempIndexPath
    #             v.selectionChanged()

    #         if not v.onDragAndDrop.isNil and v.draggedElemIndexPath.len > 1 and v.droppedElemIndexPath.len > 1 and v.draggedElemIndexPath != v.droppedElemIndexPath:
    #             v.onDragAndDrop(v.draggedElemIndexPath, v.droppedElemIndexPath)

    #         v.setNeedsDisplay()

    #         v.draggedElemIndexPath = @[]
    #         v.droppedElemIndexPath = @[]
    #         v.dropAfterItem = nil
    #         v.dropInsideItem = nil

    #         result = true

    # elif e.buttonState == bsDown:
    #     let pos = e.localPosition
    #     var y = 0.Coord
    #     let i = v.itemAtPos(pos, v.tempIndexPath, y)
    #     v.touchTarget = nil

    #     if not v.onDragAndDrop.isNil:
    #         v.dragStartLocation = pos
    #         if i.isNil:
    #             v.draggedElemIndexPath = @[]
    #         else:
    #             v.draggedElemIndexPath = v.tempIndexPath

    #     if not i.isNil:
    #         v.configureCellAUX(i, y, v.tempIndexPath)
    #         e.localPosition = i.cell.convertPointFromParent(pos)
    #         if e.localPosition.inRect(i.cell.bounds):
    #             result = i.cell.processTouchEvent(e)
    #             if result:
    #                 if i.cell.touchTarget.isNil:
    #                     v.touchTarget = i.cell
    #                 else:
    #                     v.touchTarget = i.cell.touchTarget
    #                 discard v.touchTarget.makeFirstResponder()
    #                 v.setNeedsDisplay()
    #                 return result

    #     e.localPosition = pos
    #     result = true

    # else: # Dragging
    #     let pos = e.localPosition
    #     let dragLen = pow(abs(pos.x - v.dragStartLocation.x), 2) + pow(abs(pos.y - v.dragStartLocation.y), 2)
    #     var y = 0.Coord
    #     var i = v.itemAtPos(pos, v.tempIndexPath, y)

    #     if not v.touchTarget.isNil:
    #         e.localPosition = v.touchTarget.convertPointFromParent(pos)
    #         result = v.touchTarget.processTouchEvent(e)
    #         # v.setNeedsDisplay()
    #         if result:
    #             return result
    #         e.localPosition = pos

    #     if not v.onDragAndDrop.isNil:
    #         if i.isNil:
    #             v.droppedElemIndexPath = @[]
    #         elif sqrt(dragLen) > 10:
    #             v.droppedElemIndexPath = v.tempIndexPath
    #             v.dropAfterItem = i
    #             # When mouse hovers over the row, the drop target may be one of the following:
    #             # 1. The next simbling of the row
    #             # 2. The first child of the row
    #             # 3. If the row is last child, it may be:
    #             #    a. The next sibling of row's parent.
    #             #    b. If rows parent is the last child, it may be:
    #             #       aa. The next sibling of row's parent's parent.
    #             #       bb. Recursion continues down to root.
    #             # The correct variant is determined by mouse.x location.
    #             let offset = Coord(offsetOutline + v.droppedElemIndexPath.len * offsetOutline * 2) + 6
    #             var levelsDiff = int((e.localPosition.x - offset) / (offsetOutline * 2))

    #             if i.expanded and i.children.len > 0:
    #                 v.droppedElemIndexPath.add(0)
    #             elif levelsDiff == 0:
    #                 inc v.droppedElemIndexPath[^1]
    #             elif levelsDiff > 0:
    #                 v.droppedElemIndexPath.add(0)
    #             else:
    #                 while v.droppedElemIndexPath.len > 1 and levelsDiff < 0:
    #                     let p = v.nodeAtIndexPath(v.droppedElemIndexPath[0 .. ^2])
    #                     if p.children.len > 0 and p.children[^1] == i:
    #                         i = p
    #                         inc levelsDiff
    #                         v.droppedElemIndexPath.setLen(v.droppedElemIndexPath.len - 1)
    #                     else:
    #                         break
    #                 inc v.droppedElemIndexPath[^1]

    #             if v.draggedElemIndexPath.isSubpathOfPath(v.droppedElemIndexPath):
    #                 v.droppedElemIndexPath = @[]
    #                 v.dropAfterItem = nil
    #                 v.dropInsideItem = nil
    #             else:
    #                 v.dropInsideItem = v.nodeAtIndexPath(v.droppedElemIndexPath[0 .. ^2])

    #         result = true

method acceptsFirstResponder*(v: OutlineView): bool = true

proc hasChildren(n: ItemNode): bool =
    n.expandable and n.expanded and n.children.len != 0

proc moveSelectionUp(v: OutlineView, path: var IndexPath) {.gcsafe.} =
    if path.len == 0:
        path.add(0)
        v.selectItemAtIndexPath(path)
        return

    if path[^1] > 0:
        path[^1].dec
        proc getLowestVisibleChildPath(v: OutlineView, path: var IndexPath) {.gcsafe.} =
            var nodeAtPath = v.nodeAtIndexPath(path)
            while nodeAtPath.filtered and path[^1] > 0:
                path[^1].dec
                nodeAtPath = v.nodeAtIndexPath(path)

            if nodeAtPath.filtered:
                path = path[0..^2]
                v.moveSelectionUp(path)
                return
            if nodeAtPath.hasChildren:
                path.add(nodeAtPath.children.len - 1)
                getLowestVisibleChildPath(v, path)

        v.getLowestVisibleChildPath(path)
        v.selectItemAtIndexPath(path)

    elif path.len > 1:
        v.selectItemAtIndexPath(path[0..^2])

proc moveSelectionDown(v: OutlineView, path: var IndexPath) =
    var nodeAtPath = v.nodeAtIndexPath(path)
    if nodeAtPath.isNil:
        path.add(0)

        return

    elif nodeAtPath.hasChildren:
        path.add(0)
        if v.nodeAtIndexPath(path).filtered:
            v.moveSelectionDown(path)
        else:
            v.selectItemAtIndexPath(path)
        return

    proc getLowerNeighbour(v: OutlineView, path: IndexPath) =
        if path.len > 1:
            var parent = v.nodeAtIndexPath(path[0..^2])
            if path[^1] + 1 < parent.children.len:
                var newPath = path
                newPath[^1].inc
                var n = v.nodeAtIndexPath(newPath)
                while n.filtered and newPath[^1] + 1 < parent.children.len:
                    newPath[^1].inc
                    n = v.nodeAtIndexPath(newPath)

                if n.filtered:
                    v.getLowerNeighbour(path[0..^2])
                else:
                    v.selectItemAtIndexPath(newPath)
            else:
                v.getLowerNeighbour(path[0..^2])

    v.getLowerNeighbour(path)
    v.selectItemAtIndexPath(path)

proc moveSelectionLeft(v: OutlineView) =
    let curNode = v.selectedNode
    if curNode.isNil:
        v.selectedIndexPath.add(0)
        v.selectItemAtIndexPath(v.selectedIndexPath)
        return
    if curNode.hasChildren:
        v.collapseBranch(v.selectedIndexPath)
    elif v.selectedIndexPath.len >= 2:
        v.selectItemAtIndexPath(v.selectedIndexPath[0..^2])

proc moveSelectionRight(v: OutlineView) =
    let curNode = v.selectedNode
    if curNode.isNil:
        v.selectedIndexPath.add(0)
        v.selectItemAtIndexPath(v.selectedIndexPath)
        return
    if curNode.expandable and curNode.children.len > 0 and not curNode.expanded:
        v.expandBranch(v.selectedIndexPath)
    else:
        v.moveSelectionDown(v.selectedIndexPath)

method onKeyDown*(v: OutlineView, e: var Event): bool {.gcsafe.} =
    result = true
    case e.keyCode
    of VirtualKey.Up:
        v.moveSelectionUp(v.selectedIndexPath)
    of VirtualKey.Down:
        v.moveSelectionDown(v.selectedIndexPath)
    of VirtualKey.Left:
        v.moveSelectionLeft()
    of VirtualKey.Right:
        v.moveSelectionRight()
    else:
        result = false
