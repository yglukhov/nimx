import nimx.view
import nimx.context
import nimx.composition
import nimx.font
import nimx.types
import nimx.event
import nimx.table_view_cell
import nimx.view_event_handling

import math
import variant

# Quick and dirty implementation of outline view

const offsetOutline = 6

type ItemNode = ref object
    expanded: bool
    expandable: bool
    children: seq[ItemNode]
    item: Variant
    cell: TableViewCell

type OutlineView* = ref object of View
    rootItem: ItemNode
    selectedIndexPath*: seq[int]
    numberOfChildrenInItem*: proc(item: Variant, indexPath: openarray[int]): int
    childOfItem*: proc(item: Variant, indexPath: openarray[int]): Variant
    createCell*: proc(): TableViewCell
    configureCell*: proc (cell: TableViewCell, indexPath: openarray[int])
    onSelectionChanged*: proc()
    onDragAndDrop*: proc(fromIndexPath, toIndexPath: openarray[int])
    tempIndexPath: seq[int]
    draggedElemIndexPath: seq[int] # Initial index path of the element that is currently being dragged
    droppedElemIndexPath: seq[int] # Initial index path of the element that is currently being dragged
    dropAfterItem: ItemNode

method init*(v: OutlineView, r: Rect) =
    procCall v.View.init(r)
    v.rootItem = ItemNode.new()
    v.tempIndexPath = newSeq[int]()
    v.selectedIndexPath = newSeq[int]()

const rowHeight = 20.Coord

var disclosureTriangleComposition = newComposition """
uniform float uAngle;
void compose() {
    vec2 center = vec2(bounds.x + bounds.z / 2.0, bounds.y + bounds.w / 2.0 - 1.0);
    float triangle = sdRegularPolygon(center, 4.0, 3, uAngle);
    drawShape(triangle, vec4(0.0, 0, 0, 1));
}
"""

proc drawDisclosureTriangle(disclosed: bool, r: Rect) =
    disclosureTriangleComposition.draw r:
        setUniform("uAngle", if disclosed: Coord(PI / 2.0) else: Coord(0))
    discard

template xOffsetBasedOnTempIndexPath(v: OutlineView): Coord =
    Coord(offsetOutline + v.tempIndexPath.len * offsetOutline * 2)

proc drawNode(v: OutlineView, n: ItemNode, y: var Coord) =
    let c = currentContext()
    if n.cell.isNil:
        n.cell = v.createCell()
    n.cell.selected = v.tempIndexPath == v.selectedIndexPath
    let indent = v.xOffsetBasedOnTempIndexPath
    n.cell.setFrame(newRect(indent + 6, y, v.bounds.width - indent - 6, rowHeight))
    v.configureCell(n.cell, v.tempIndexPath)
    n.cell.drawWithinSuperview()
    if n.expandable and n.children.len > 0:
        drawDisclosureTriangle(n.expanded, newRect(indent - offsetOutline * 2, y, offsetOutline * 2, rowHeight))

    y += rowHeight

    if n == v.dropAfterItem:
        # Show drop marker
        c.fillColor = newColor(0.27, 0.44, 0.85)
        c.strokeWidth = 0
        let offset = Coord(offsetOutline + v.droppedElemIndexPath.len * offsetOutline * 2) + 6
        c.drawRect(newRect(offset, y, v.bounds.width - offset, 2))
        const circleRadius = 3
        c.drawEllipseInRect(newRect(offset - circleRadius, y - circleRadius, circleRadius * 2, circleRadius * 2))

    if n.expanded and not n.children.isNil:
        let lastIndex = v.tempIndexPath.len
        v.tempIndexPath.add(0)
        for i, c in n.children:
            v.tempIndexPath[lastIndex] = i
            v.drawNode(c, y)
        v.tempIndexPath.setLen(lastIndex)

method draw*(v: OutlineView, r: Rect) =
    var y = 0.Coord
    if not v.rootItem.children.isNil:
        v.tempIndexPath.setLen(1)
        for i, c in v.rootItem.children:
            v.tempIndexPath[0] = i
            v.drawNode(c, y)

proc nodeAtIndexPath(v: OutlineView, indexPath: openarray[int]): ItemNode =
    result = v.rootItem
    for i in indexPath:
        result = result.children[i]

proc getExpandedRowsCount(node: ItemNode): int =
    result = node.children.len

    for i in node.children:
        if i.expanded:
            result += i.getExpandedRowsCount()

proc checkViewSize(v: OutlineView) =
    var size: Size
    size.height = Coord(v.rootItem.getExpandedRowsCount()) * rowHeight
    size.width = 300#v.bounds.width

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

proc setBranchExpanded*(v: OutlineView, expanded: bool, indexPath: openarray[int]) =
    var path = newSeq[int]()

    for i, index in indexPath:
        path.add(index)
        v.setRowExpanded(expanded, path)

proc expandBranch*(v: OutlineView, indexPath: openarray[int]) =
    v.setBranchExpanded(true, indexPath)

proc collapseBranch*(v: OutlineView, indexPath: openarray[int]) =
    v.setBranchExpanded(false, indexPath)

proc itemAtPos(v: OutlineView, n: ItemNode, p: Point, y: var Coord): ItemNode =
    y += rowHeight
    if p.y < y: return n
    if n.expanded and not n.children.isNil:
        let lastIndex = v.tempIndexPath.len
        v.tempIndexPath.add(0)
        for i, c in n.children:
            v.tempIndexPath[lastIndex] = i
            result = v.itemAtPos(c, p, y)
            if not result.isNil: return
        v.tempIndexPath.setLen(lastIndex)

proc itemAtPos(v: OutlineView, p: Point): ItemNode =
    v.tempIndexPath.setLen(1)
    var y = 0.Coord
    if not v.rootItem.children.isNil:
        for i, c in v.rootItem.children:
            v.tempIndexPath[0] = i
            result = v.itemAtPos(c, p, y)
            if not result.isNil: break

proc reloadDataForNode(v: OutlineView, n: ItemNode) =
    let childrenCount = v.numberOfChildrenInItem(n.item, v.tempIndexPath)
    if childrenCount > 0 and n.children.isNil:
        n.children = newSeq[ItemNode](childrenCount)
    elif not n.children.isNil:
        n.children.setLen(childrenCount)
    let lastIndex = v.tempIndexPath.len
    v.tempIndexPath.add(0)
    for i in 0 ..< childrenCount:
        v.tempIndexPath[lastIndex] = i
        if n.children[i].isNil:
            n.children[i] = ItemNode(expandable: true)
        if not v.childOfItem.isNil:
            n.children[i].item = v.childOfItem(n.item, v.tempIndexPath)
        v.reloadDataForNode(n.children[i])
    v.tempIndexPath.setLen(lastIndex)

proc reloadData*(v: OutlineView) =
    v.tempIndexPath.setLen(0)
    v.reloadDataForNode(v.rootItem)

template selectionChanged(v: OutlineView) =
    if not v.onSelectionChanged.isNil: v.onSelectionChanged()

proc selectItemAtIndexPath*(v: OutlineView, ip: seq[int]) =
    v.selectedIndexPath = ip
    v.selectionChanged()

proc isSubpathOfPath(subpath, path: openarray[int]): bool =
    if path.len >= subpath.len:
        var i = 0
        while i < subpath.len:
            if path[i] != subpath[i]: return
            inc i
        return true

method onTouchEv*(v: OutlineView, e: var Event): bool =
    if e.buttonState == bsUp:
        let pos = e.localPosition
        let i = v.itemAtPos(pos)
        if not i.isNil:
            if pos.x < v.xOffsetBasedOnTempIndexPath and i.expandable:
                i.expanded = not i.expanded
                v.checkViewSize()
            elif v.tempIndexPath == v.selectedIndexPath:
                v.selectedIndexPath.setLen(0)
                v.selectionChanged()
            else:
                v.selectedIndexPath = @(v.tempIndexPath)
                v.selectionChanged()
            if not v.onDragAndDrop.isNil and v.draggedElemIndexPath.len > 1 and v.droppedElemIndexPath.len > 1 and v.draggedElemIndexPath != v.droppedElemIndexPath:
                v.onDragAndDrop(v.draggedElemIndexPath, v.droppedElemIndexPath)
            v.setNeedsDisplay()
        v.draggedElemIndexPath = @[]
        v.droppedElemIndexPath = @[]
        v.dropAfterItem = nil
    elif not v.onDragAndDrop.isNil:
        if e.buttonState == bsDown:
            let pos = e.localPosition
            let i = v.itemAtPos(pos)
            if i.isNil:
                v.draggedElemIndexPath = @[]
            else:
                v.draggedElemIndexPath = @(v.tempIndexPath)
        else: # Dragging
            let pos = e.localPosition
            var i = v.itemAtPos(pos)
            if i.isNil:
                v.droppedElemIndexPath = @[]
            else:
                v.droppedElemIndexPath = @(v.tempIndexPath)
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
                    echo 4
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

    result = true
