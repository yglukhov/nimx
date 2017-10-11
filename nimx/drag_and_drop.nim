import view
import types
import class_registry
import variant

import nimx.image
import nimx.pasteboard.pasteboard_item

const DragPboardKindDefault* = "nimx.dragged.default"

type DragSystem* = ref object
    rect*: Rect
    itemPosition*: Point
    pItem*: PasteboardItem
    prevTarget*: View
    image*: Image

var gDragSystem: DragSystem = nil
proc currentDragSystem*(): DragSystem =
    if gDragSystem.isNil:
        gDragSystem = new(DragSystem)
        gDragSystem.rect = newRect(0, 0, 30, 30)

    result = gDragSystem


proc startDrag*(item: PasteboardItem, image: Image = nil) =
    currentDragSystem().pItem = item
    currentDragSystem().image = image
    currentDragSystem().prevTarget = nil

proc stopDrag*() =
    currentDragSystem().pItem = nil
    currentDragSystem().prevTarget = nil

proc newDragDestinationDelegate*(): DragDestinationDelegate =
    result.new()

method onDrag*(dd: DragDestinationDelegate, target: View, i: PasteboardItem) {.base.} = discard
method onDrop*(dd: DragDestinationDelegate, target: View, i: PasteboardItem) {.base.} = discard
method onDragEnter*(dd: DragDestinationDelegate, target: View, i: PasteboardItem) {.base.} = discard
method onDragExit*(dd: DragDestinationDelegate, target: View, i: PasteboardItem) {.base.} = discard

proc findSubviewAtPointAux*(v: View, p: Point, target: var View): View =
    for i in countdown(v.subviews.len - 1, 0):
        let s = v.subviews[i]
        var pp = s.convertPointFromParent(p)
        if pp.inRect(s.bounds):
            if not v.dragDestination.isNil:
                target = v
            result = s.findSubviewAtPointAux(pp, target)
            if not result.isNil:
                break

    if result.isNil:
        result = v
        if not result.dragDestination.isNil:
            target = result


proc findSubviewAtPoint*(v: View, p: Point): View =
    discard v.findSubviewAtPointAux(p, result)
    if result == v: result = nil