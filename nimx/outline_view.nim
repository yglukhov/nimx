import nimx.view
import nimx.context
import nimx.composition
import nimx.font
import nimx.types
import nimx.event
import nimx.table_view_cell
import nimx.view_event_handling
import nimx.view_event_handling_new

import scroll_view

import math
import variant

# Quick and dirty implementation of outline view

const offsetOutline = 6

type ItemNode = ref object
    expanded: bool
    expandable: bool
    filtered: bool
    children: seq[ItemNode]
    item: Variant
    cell: TableViewCell

type
    OutlineView* = ref object of View
        rootItem: ItemNode
        selectedIndexPath*: IndexPath
        numberOfChildrenInItem*: proc(item: Variant, indexPath: openarray[int]): int
        mDisplayFilter: proc(item: Variant):bool
        childOfItem*: proc(item: Variant, indexPath: openarray[int]): Variant
        createCell*: proc(): TableViewCell
        configureCell*: proc (cell: TableViewCell, indexPath: openarray[int])
        onSelectionChanged*: proc()
        onDragAndDrop*: proc(fromIndexPath, toIndexPath: openarray[int])
        tempIndexPath: IndexPath
        draggedElemIndexPath: IndexPath # Initial index path of the element that is currently being dragged
        droppedElemIndexPath: IndexPath # Initial index path of the element that is currently being dragged
        dropAfterItem: ItemNode
        dropInsideItem: ItemNode
        dragStartLocation: Point

    IndexPath* = seq[int]

method init*(v: OutlineView, r: Rect) =
    procCall v.View.init(r)
    v.rootItem = ItemNode.new()
    v.rootItem.expandable = true
    v.rootItem.expanded = true
    v.tempIndexPath = @[]
    v.selectedIndexPath = @[]

const rowHeight = 20.Coord

proc drawDisclosureTriangle(disclosed: bool, r: Rect) =
    currentContext().drawTriangle(r, if disclosed: Coord(PI / 2.0) else: Coord(0))

template xOffsetForIndexPath(ip: IndexPath): Coord =
    Coord(offsetOutline + ip.len * offsetOutline * 2)

proc configureCellAUX(v: OutlineView, n: ItemNode, y: Coord, indexPath: IndexPath)=
    if n.cell.isNil:
        n.cell = v.createCell()
    n.cell.selected = indexPath == v.selectedIndexPath
    let indent = xOffsetForIndexPath(indexPath)
    n.cell.setFrame(newRect(indent + 6, y, v.bounds.width - indent - 6, rowHeight))
    v.configureCell(n.cell, indexPath)

proc drawNode(v: OutlineView, n: ItemNode, y: var Coord, indexPath: var IndexPath) =
    if n.filtered: return
    let c = currentContext()
    v.configureCellAUX(n, y, indexPath)
    n.cell.drawWithinSuperview()
    if n.expandable and n.children.len > 0:
        drawDisclosureTriangle(n.expanded, newRect(n.cell.frame.x - 6 - offsetOutline * 2 - rowHeight * 0.5 , y - rowHeight * 0.5, rowHeight * 2.0, rowHeight * 2.0))

    y += rowHeight

    if n == v.dropInsideItem:
        c.fillColor = newColor(0.44, 0.55, 0.90, 0.3)
        c.strokeColor = newColor(0.27, 0.44, 0.85, 0.3)
        c.strokeWidth = 2
        # let offset = Coord(offsetOutline + (v.droppedElemIndexPath.len - 1) * offsetOutline * 2) + 6
        c.drawRoundedRect(n.cell.frame, 4)
    elif n == v.dropAfterItem:
        # Show drop marker
        c.fillColor = newColor(0.27, 0.44, 0.85)
        c.strokeWidth = 0
        let offset = Coord(offsetOutline + v.droppedElemIndexPath.len * offsetOutline * 2) + 6
        c.drawRect(newRect(offset, y, v.bounds.width - offset, 2))
        const circleRadius = 3
        c.drawEllipseInRect(newRect(offset - circleRadius, y - circleRadius, circleRadius * 2, circleRadius * 2))

    if n.expanded and not n.children.isNil:
        let lastIndex = indexPath.len
        indexPath.add(0)
        for i, c in n.children:
            indexPath[lastIndex] = i
            v.drawNode(c, y, indexPath)
        indexPath.setLen(lastIndex)

method draw*(v: OutlineView, r: Rect) =
    var y = 0.Coord
    if not v.rootItem.children.isNil:
        v.tempIndexPath.setLen(1)
        for i, c in v.rootItem.children:
            v.tempIndexPath[0] = i
            v.drawNode(c, y, v.tempIndexPath)

iterator nodesOnPath(v: OutlineView, indexPath: openarray[int]): ItemNode =
    var n = v.rootItem
    for i in indexPath:
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

proc checkViewSize(v: OutlineView) =
    var size: Size
    size.height = Coord(v.rootItem.getExposedRowsCount - 1) * rowHeight    # rootItem itself is invisible
    size.width = v.bounds.width

    if not v.superview.isNil:
        v.superview.subviewDidChangeDesiredSize(v, size)

proc setRowExpanded*(v: OutlineView, expanded: bool, indexPath: openarray[int]) =
    v.nodeAtIndexPath(indexPath).expanded = expanded
    v.checkViewSize()

proc expandRow*(v: OutlineView, indexPath: openarray[int]) =
    v.setRowExpanded(true, indexPath)

proc collapseRow*(v: OutlineView, indexPath: openarray[int]) =
    v.setRowExpanded(false, indexPath)

proc itemAtIndexPath*(v: OutlineView, indexPath: openarray[int]): Variant =
    v.nodeAtIndexPath(indexPath).item

proc cellAtIndexPath*(v: OutlineView, indexPath: openarray[int]): TableViewCell=
    v.nodeAtIndexPath(indexPath).cell

proc setBranchExpanded*(v: OutlineView, expanded: bool, indexPath: openarray[int]) =
    if expanded:
        for n in v.nodesOnPath(indexPath):
            n.expanded = true
        v.checkViewSize()
    else:
        v.setRowExpanded(false, indexPath)

proc expandBranch*(v: OutlineView, indexPath: openarray[int]) =
    v.setBranchExpanded(true, indexPath)

proc collapseBranch*(v: OutlineView, indexPath: openarray[int]) =
    v.setBranchExpanded(false, indexPath)

proc itemAtPos(v: OutlineView, n: ItemNode, p: Point, y: var Coord, indexPath: var IndexPath): ItemNode =
    y += rowHeight
    if p.y < y: return n
    if n.expanded and not n.children.isNil:
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
    if not v.rootItem.children.isNil:
        for i, c in v.rootItem.children:
            indexPath[0] = i
            if c.filtered: continue
            result = v.itemAtPos(c, p, y, indexPath)
            if not result.isNil: 
                y -= rowHeight
                break

proc reloadDataForNode(v: OutlineView, n: ItemNode, indexPath: var IndexPath) =
    let childrenCount = v.numberOfChildrenInItem(n.item, indexPath)
    if childrenCount > 0 and n.children.isNil:
        n.children = newSeq[ItemNode](childrenCount)
    elif not n.children.isNil:
        when defined(js):
            let oldLen = n.children.len
        n.children.setLen(childrenCount)
        when defined(js): # Workaround for nim bug. Increasing seq len does not init items in js.
            for i in oldLen ..< childrenCount: n.children[i] = ItemNode(expandable: true)

    let lastIndex = indexPath.len
    indexPath.add(0)

    if not v.mDisplayFilter.isNil:
        n.filtered = not v.mDisplayFilter(n.item)
    else:
        n.filtered = false

    for i in 0 ..< childrenCount:
        indexPath[lastIndex] = i
        if n.children[i].isNil:
            n.children[i] = ItemNode(expandable: true)
        if not v.childOfItem.isNil:
            n.children[i].item = v.childOfItem(n.item, indexPath)
        v.reloadDataForNode(n.children[i], indexPath)

        if not n.children[i].filtered:
            n.filtered = false

    indexPath.setLen(lastIndex)

proc reloadData*(v: OutlineView) =
    v.tempIndexPath.setLen(0)
    v.reloadDataForNode(v.rootItem, v.tempIndexPath)
    v.checkViewSize()

proc setDisplayFilter*(v: OutlineView, f: proc(item: Variant):bool)=
    v.mDisplayFilter = f
    v.reloadData()

template selectionChanged(v: OutlineView) =
    if not v.onSelectionChanged.isNil: v.onSelectionChanged()

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
    result = procCall v.View.onTouchEv(e)

    if e.buttonState == bsUp:
        let pos = e.localPosition
        var y = 0.Coord
        let i = v.itemAtPos(pos, v.tempIndexPath, y)
        
        if not v.touchTarget.isNil:
            e.localPosition = v.touchTarget.convertPointFromParent(pos)
            if v.touchTarget.processTouchEvent(e):
                return true

        v.touchTarget = nil

        if not i.isNil:
            if pos.x < xOffsetForIndexPath(v.tempIndexPath) and i.expandable:
                i.expanded = not i.expanded
                v.checkViewSize()
            elif v.tempIndexPath != v.selectedIndexPath:
                v.selectedIndexPath = v.tempIndexPath
                v.selectionChanged()

            if not v.onDragAndDrop.isNil and v.draggedElemIndexPath.len > 1 and v.droppedElemIndexPath.len > 1 and v.draggedElemIndexPath != v.droppedElemIndexPath:
                v.onDragAndDrop(v.draggedElemIndexPath, v.droppedElemIndexPath)

            v.setNeedsDisplay()

            v.draggedElemIndexPath = @[]
            v.droppedElemIndexPath = @[]
            v.dropAfterItem = nil
            v.dropInsideItem = nil
            
            result = true

    elif e.buttonState == bsDown:
        let pos = e.localPosition
        var y = 0.Coord
        let i = v.itemAtPos(pos, v.tempIndexPath, y)
        v.touchTarget = nil

        if not v.onDragAndDrop.isNil:
            v.dragStartLocation = pos
            if i.isNil:
                v.draggedElemIndexPath = @[]
            else:
                v.draggedElemIndexPath = v.tempIndexPath
        
        if not i.isNil:
            v.configureCellAUX(i, y, v.tempIndexPath)
            e.localPosition = i.cell.convertPointFromParent(pos)
            if e.localPosition.inRect(i.cell.bounds):
                result = i.cell.processTouchEvent(e)
                if result:
                    v.touchTarget = i.cell
                    discard v.touchTarget.makeFirstResponder()
                    return result

        e.localPosition = pos
        result = true

    else: # Dragging
        let pos = e.localPosition
        let dragLen = pow(abs(pos.x - v.dragStartLocation.x), 2) + pow(abs(pos.y - v.dragStartLocation.y), 2)
        var y = 0.Coord
        var i = v.itemAtPos(pos, v.tempIndexPath, y)

        if not v.touchTarget.isNil:
            e.localPosition = v.touchTarget.convertPointFromParent(pos)
            result = v.touchTarget.processTouchEvent(e)
            # v.setNeedsDisplay()
            if result:
                return result
            e.localPosition = pos
        
        if not v.onDragAndDrop.isNil:
            if i.isNil:
                v.droppedElemIndexPath = @[]
            elif sqrt(dragLen) > 10:
                v.droppedElemIndexPath = v.tempIndexPath
                v.dropAfterItem = i
                # When mouse hovers over the row, the drop target may be one of the following:
                # 1. The next simbling of the row
                # 2. The first child of the row
                # 3. If the row is last child, it may be:
                #    a. The next sibling of row's parent.
                #    b. If rows parent is the last child, it may be:
                #       aa. The next sibling of row's parent's parent.
                #       bb. Recursion continues down to root.
                # The correct variant is determined by mouse.x location.
                let offset = Coord(offsetOutline + v.droppedElemIndexPath.len * offsetOutline * 2) + 6
                var levelsDiff = int((e.localPosition.x - offset) / (offsetOutline * 2))

                if i.expanded and i.children.len > 0:
                    v.droppedElemIndexPath.add(0)
                elif levelsDiff == 0:
                    inc v.droppedElemIndexPath[^1]
                elif levelsDiff > 0:
                    v.droppedElemIndexPath.add(0)
                else:
                    while v.droppedElemIndexPath.len > 1 and levelsDiff < 0:
                        let p = v.nodeAtIndexPath(v.droppedElemIndexPath[0 .. ^2])
                        if p.children.len > 0 and p.children[^1] == i:
                            i = p
                            inc levelsDiff
                            v.droppedElemIndexPath.setLen(v.droppedElemIndexPath.len - 1)
                        else:
                            break
                    inc v.droppedElemIndexPath[^1]

                if v.draggedElemIndexPath.isSubpathOfPath(v.droppedElemIndexPath):
                    v.droppedElemIndexPath = @[]
                    v.dropAfterItem = nil
                    v.dropInsideItem = nil
                else:
                    v.dropInsideItem = v.nodeAtIndexPath(v.droppedElemIndexPath[0 .. ^2])

            result = true


method acceptsFirstResponder*(v: OutlineView): bool = true

proc hasChildren(n: ItemNode): bool =
    n.expandable and n.expanded and n.children.len != 0

proc moveSelectionUp(v: OutlineView, path: var IndexPath) =
    if path.len == 0:
        path.add(0)
        v.selectItemAtIndexPath(path)
        return

    if path[^1] > 0:
        path[^1].dec
        proc getLowestVisibleChildPath(v: OutlineView, path: var IndexPath) =
            var nodeAtPath = v.nodeAtIndexPath(path)
            while nodeAtPath.filtered and path[^1] > 0:
                path[^1].dec
                nodeAtPath = v.nodeAtIndexPath(path)

            if nodeAtPath.hasChildren:
                path.add(nodeAtPath.children.len - 1)
                getLowestVisibleChildPath(v, path)

        v.getLowestVisibleChildPath(path)
        v.selectItemAtIndexPath(path)
    elif path.len > 1:
        v.selectItemAtIndexPath(path[0..^2])

proc moveSelectionDown(v: OutlineView, path: var IndexPath) =
    var nodeAtPath = v.nodeAtIndexPath(path)
    if nodeAtPath.isNil or nodeAtPath.hasChildren:
        path.add(0)
        v.selectItemAtIndexPath(path)
        return

    proc getLowerNeighbour(v: OutlineView, path: IndexPath) =
        if path.len >= 2:
            var parent = v.nodeAtIndexPath(path[0..^2])
            if path[^1] + 1 < parent.children.len:
                var newPath = path
                newPath[^1].inc
                var n = v.nodeAtIndexPath(newPath)
                while n.filtered and newPath[^1] + 1 < parent.children.len:
                    newPath[^1].inc
                    n = v.nodeAtIndexPath(newPath)

                if n.filtered and path.len >= 2:
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

method onKeyDown*(v: OutlineView, e: var Event): bool =
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
