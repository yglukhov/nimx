import view
import event
export event
import system_logger
import typetraits
import drag_and_drop
import logging

method onGestEvent*(d: GestureDetector, e: var Event) : bool {.base.} = discard
method onScroll*(v: View, e: var Event): bool = discard

method name*(v: View): string {.base.} =
    result = "View"

method onTouchEv*(v: View, e: var Event): bool {.base.} =
    if not v.gestureDetectors.isNil:
        for d in v.gestureDetectors:
            let r = d.onGestEvent(e)
            result = result or r

    if e.buttonState == bsDown:
        if v.acceptsFirstResponder:
            result = v.makeFirstResponder()

method onInterceptTouchEv*(v: View, e: var Event): bool {.base.} =
    discard

method onListenTouchEv*(v: View, e: var Event): bool {.base.} =
    discard

proc isMainWindow(v: View, e : var Event): bool =
    result = v == e.window

method onMouseIn*(v: View, e: var Event) {.base.} =
    discard

method onMouseOver*(v: View, e: var Event) {.base.} =
    discard

method onMouseOut*(v: View, e: var Event) {.base.} =
    discard

proc handleMouseOverEvent(v: View, e : var Event) =
    let localPosition = e.localPosition
    for vi in v.window.mouseOverListeners:
        let r = vi.convertRectToWindow(vi.bounds)
        e.localPosition = vi.convertPointFromWindow(localPosition)
        if localPosition.inRect(r):
            if not vi.mouseInside:
                vi.onMouseIn(e)
                vi.mouseInside = true
            else:
                vi.onMouseOver(e)
        elif vi.mouseInside:
            vi.mouseInside = false
            vi.onMouseOut(e)
    e.localPosition = localPosition

proc processDragEvent*(b: DragSystem, e: var Event) =
    b.itemPosition = e.position
    if b.pItem.isNil:
        return

    e.window.needsDisplay = true
    let target = e.window.findSubviewAtPoint(e.position)
    var dropDelegate: DragDestinationDelegate
    if not target.isNil:
        dropDelegate = target.dragDestination

    if e.buttonState == bsUp:
        if not dropDelegate.isNil:
            dropDelegate.onDrop(target, b.pItem)
        stopDrag()
        return

    if b.prevTarget != target:
        if not b.prevTarget.isNil and not b.prevTarget.dragDestination.isNil:
            b.prevTarget.dragDestination.onDragExit(b.prevTarget, b.pItem)
        if not target.isNil and not dropDelegate.isNil:
            dropDelegate.onDragEnter(target, b.pItem)

    elif not target.isNil and not target.dragDestination.isNil:
            dropDelegate.onDrag(target, b.pItem)

    b.prevTarget = target

proc processTouchEvent*(v: View, e : var Event): bool =
    # if e.buttonState != bsUnknown:
    #     info "touch event ", e.id, " native ", e.pointerId, " state ", e.buttonState

    if e.buttonState == bsDown:
        if v.hidden: return false
        v.interceptEvents = false
        v.touchTarget = nil
        if v.subviews.isNil or v.subviews.len == 0:
            result = v.onTouchEv(e)
            if result and e.target.isNil:
                # info "settarget ", v.name
                e.target = v
        else:
            if v.onInterceptTouchEv(e):
                v.interceptEvents = true
                result = v.onTouchEv(e)
            else:
                let localPosition = e.localPosition
                for i in countdown(v.subviews.len - 1, 0):
                    let s = v.subviews[i]
                    e.localPosition = s.convertPointFromParent(localPosition)
                    if e.localPosition.inRect(s.bounds):
                        result = s.processTouchEvent(e)
                        if result:
                            v.touchTarget = s
                            if e.target.isNil:
                                e.target = s
                                # info "settarget 3", s.name
                            break

                if result and v.onListenTouchEv(e):
                    discard v.onTouchEv(e)
                if not result:
                    e.localPosition = localPosition
                    result = v.onTouchEv(e)
                    if result and e.target.isNil:
                        e.target = v
                        # info "settarget 2", v.name
    # elif e.buttonState != bsCancel:
    else:
        if numberOfActiveTouches() > 0:
            # if not e.target.isNil:
            #     info "touch ", e.id, " state ", e.buttonState , " target ", e.target.name
            # else:
            #     info "touch ", e.id, " state ", e.buttonState , " target nil"
            if v.subviews.isNil or v.subviews.len == 0:
                # single view
                if not v.isMainWindow(e):
                    result = v.onTouchEv(e)
            else:
                # group view
                if v.interceptEvents:
                    if not v.isMainWindow(e):
                        result = v.onTouchEv(e)
                else:
                    if (not v.isMainWindow(e)) and v.onInterceptTouchEv(e):
                        v.interceptEvents = true
                        result = v.onTouchEv(e)
                    else:
                        if not e.target.isNil:
                            # if e.buttonState == bsUp:
                            #     echo "uptouch at ", e.target.name

                            var localPosition = e.localPosition
                            e.localPosition = e.target.convertPointFromWindow(localPosition)
                            if v.onListenTouchEv(e):
                                discard v.onTouchEv(e)
                            result = e.target.onTouchEv(e)
                            e.localPosition = localPosition

                        # if not v.touchTarget.isNil:
                        #     let target = v.touchTarget
                        #     var localPosition = e.localPosition
                        #     e.localPosition = target.convertPointFromParent(localPosition)
                        #     if v.onListenTouchEv(e):
                        #         discard v.onTouchEv(e)
                        #     result = target.processTouchEvent(e)
                        #     e.localPosition = localPosition
                        else:
                            if not v.isMainWindow(e):
                                result = v.onTouchEv(e)
        else:
            if v.isMainWindow(e):
                v.handleMouseOverEvent(e)

    # else: #bsCancel
    #     if not e.target.isNil:
    #         discard e.target.onTouchEv(e)

    if e.buttonState == bsUp:
        if v.isMainWindow(e) and numberOfActiveTouches() == 1:
            v.touchTarget = nil
            v.interceptEvents = false

proc processMouseWheelEvent*(v: View, e : var Event): bool =
    if v.hidden: return false
    let localPosition = e.localPosition
    for i in countdown(v.subviews.len - 1, 0):
        let s = v.subviews[i]
        e.localPosition = s.convertPointFromParent(localPosition)
        if e.localPosition.inRect(s.bounds):
            result = s.processMouseWheelEvent(e)
            if result:
                break
    if not result:
        e.localPosition = localPosition
        result = v.onScroll(e)
