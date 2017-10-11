import view
import types
import class_registry
import variant

import nimx.image
import nimx.pasteboard.pasteboard

const DragPboardKind* = "io.github.gutyria.nimx"

type BaseDragAndDrop* = ref object of DragAndDrop

type DraggedItem* = ref object
    data*: Variant
    image*: Image
    position*: Point
    target*: View
    pastboard*: PasteboardItem

type DragSystem* = ref object
    rect*: Rect
    currentPos*: Point
    pItem*: PasteboardItem
    item*: DraggedItem
    prevTarget*: View

var gDragSystem: DragSystem = nil
proc currentDragSystem*(): DragSystem =
    if gDragSystem.isNil:
        gDragSystem = new(DragSystem)
        gDragSystem.rect = newRect(0, 0, 30, 30)

    result = gDragSystem

proc startDrag*(item: DraggedItem) =
    echo "startDrag"
    # let dpi = newPasteboardItem(DragPboardKind, $s.jsonNode)
    currentDragSystem().item = item
    currentDragSystem().prevTarget = nil

proc stopDrag*() =
    echo "stop drag"
    currentDragSystem().item = nil
    currentDragSystem().prevTarget = nil


proc newDragAndDrop*(): BaseDragAndDrop =
    result.new()
    result.activateStep = 4.0

method onDrag*(dd: DragAndDrop, i: DraggedItem) {.base.} = discard
method onDrop*(dd: DragAndDrop, i: DraggedItem) {.base.} = discard
method onDragEnter*(dd: DragAndDrop, i: DraggedItem) {.base.} = discard
method onDragExit*(dd: DragAndDrop, i: DraggedItem) {.base.} = discard

# method onDrag*(v: DragAndDrop, i: DraggedItem) {.base.} = discard
# method onDrop*(dd: DragAndDrop, i: DraggedItem) {.base.} = discard
# method onDragEnter*(dd: DragAndDrop, i: DraggedItem) {.base.} = discard
# method onDragExit*(dd: DragAndDrop, i: DraggedItem) {.base.} = discard

proc findSubviewAtPointAux*(v: View, p: Point, target: var View): View =
    for i in countdown(v.subviews.len - 1, 0):
        let s = v.subviews[i]
        var pp = s.convertPointFromParent(p)
        if pp.inRect(s.bounds):
            if not v.dragAndDropDelegate.isNil:
                target = v
            result = s.findSubviewAtPointAux(pp, target)
            if not result.isNil:
                break

    if result.isNil:
        result = v
        if not result.dragAndDropDelegate.isNil:
            target = result


proc findSubviewAtPoint*(v: View, p: Point): View =
    discard v.findSubviewAtPointAux(p, result)
    if result == v: result = nil


registerClass(BaseDragAndDrop)
