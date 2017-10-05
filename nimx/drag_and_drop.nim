
import view
import types
import class_registry
import event

type BaseDragAndDrop* = ref object of DragAndDrop

proc newDragAndDrop*(): BaseDragAndDrop =
    result.new()
    result.activateStep = 4.0

method onDragStart*(dd: BaseDragAndDrop, e: DragEvent) {.base.} = discard
method onDrag*(dd: BaseDragAndDrop, e: DragEvent) {.base.} = discard
method onDrop*(dd: BaseDragAndDrop, e: DragEvent) {.base.} = discard

method onDragOver*(dd: DragAndDrop, e: DragEvent) {.base.} = discard
method onDragOverEnter*(dd: DragAndDrop, e: DragEvent) {.base.} = discard
method onDragOverExit*(dd: DragAndDrop, e: DragEvent) {.base.} = discard
method onDropOver*(dd: DragAndDrop, e: DragEvent) {.base.} = discard

proc findSubviewAtPointAux(v: View, p: Point): View =
    for i in countdown(v.subviews.len - 1, 0):
        let s = v.subviews[i]
        var pp = s.convertPointFromParent(p)
        if pp.inRect(s.bounds):
            result = s.findSubviewAtPointAux(pp)
            if not result.isNil:
                break

    if result.isNil:
        result = v

proc findSubviewAtPoint(v: View, p: Point): View =
    result = v.findSubviewAtPointAux(p)
    if result == v: result = nil

var prevTarget: View = nil

method onDragEv*(dd: BaseDragAndDrop, v: View, e: Event): bool =
    result = true

    # echo "e.buttonState ", e.buttonState
    if e.buttonState == bsDown:
        dd.mStartPos = e.position
        dd.dragState = dsWait

    let target = e.window.findSubviewAtPoint(dd.mCurrentPos)
    var dragEv: DragEvent
    dragEv.draggedView = v
    dragEv.targetView = target
    dragEv.currentPos = e.position

    if distanceTo(dd.mStartPos, e.position) >= dd.activateStep and  dd.dragState == dsWait:
        dd.dragState = dsDragged
        dd.mCurrentPos = e.position
        result = true
        dd.onDragStart(dragEv)

    if e.buttonState == bsUp:
        dd.dragState = dsWait
        result = true
        dd.onDrop(dragEv)
        prevTarget = nil

        if not target.isNil and not target.dragAndDropDelegate.isNil:
            target.dragAndDropDelegate.onDropOver(dragEv)

    if dd.dragState == dsDragged:
        dragEv.deltaPos = e.position - dd.mCurrentPos
        dd.mCurrentPos = e.position
        dd.onDrag(dragEv)

        if prevTarget != target:
            if not prevTarget.isNil and not prevTarget.dragAndDropDelegate.isNil:
                dragEv.targetView = prevTarget
                prevTarget.dragAndDropDelegate.onDragOverExit(dragEv)
            if not target.isNil and not target.dragAndDropDelegate.isNil:
                target.dragAndDropDelegate.onDragOverEnter(dragEv)

        elif not target.isNil and not target.dragAndDropDelegate.isNil:
                target.dragAndDropDelegate.onDragOver(dragEv)

    prevTarget = target
    # echo "dd.dragState ", dd.dragState, "  start ", dd.mStartPos, "  curr  ", dd.mCurrentPos

registerClass(BaseDragAndDrop)
