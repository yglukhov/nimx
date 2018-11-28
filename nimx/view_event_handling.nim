import view, event, drag_and_drop, tables

export event

method onKeyDown*(v: View, e: var Event): bool {.base.} = discard
method onKeyUp*(v: View, e: var Event): bool {.base.} = discard
method onTextInput*(v: View, s: string): bool {.base.} = discard
method onGestEvent*(d: GestureDetector, e: var Event) : bool {.base.} = discard
method onTouchCancel*(d: GestureDetector, e: var Event) : bool {.base.} = discard
method onScroll*(v: View, e: var Event): bool {.base.} = discard

method name*(v: View): string {.base.} =
    result = "View"

method onTouchEv*(v: View, e: var Event): bool {.base.} =
    for d in v.gestureDetectors:
        let r = d.onGestEvent(e)
        result = result or r

    if e.buttonState == bsDown:
        if v.acceptsFirstResponder:
            result = v.makeFirstResponder()

method onTouchCancel*(v: View, e: var Event): bool {.base.} =
    if v.gestureDetectors.len > 0:
        for d in v.gestureDetectors:
            let r = d.onTouchCancel(e)
            result = result or r

proc cancelAllTouches*(v: View) =
    if not v.window.isNil:
        for touch, view in v.window.mCurrentTouches:
            var ev = newEvent(etCancel, pointerId = touch)
            discard view.onTouchCancel(ev)

        v.window.mCurrentTouches.clear()


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

proc getCurrentTouches(e: Event): TableRef[int, View] {.inline.}=
    assert(not e.window.isNil, "Internal error")
    result = e.window.mCurrentTouches

proc setTouchTarget(e: Event, v: View)=
    let ct = e.getCurrentTouches()
    if e.pointerId notin ct and not v.window.isNil:
        ct[e.pointerId] = v

proc getTouchTarget(e: Event): View =
    let ct = e.getCurrentTouches()
    if e.pointerId in ct:
        var r = ct[e.pointerId]
        if not r.window.isNil:
            result = r
        else:
            ct.del(e.pointerId)

proc removeTouchTarget(e: Event)=
    let ct = e.getCurrentTouches()
    ct.del(e.pointerId)

proc processTouchEvent*(v: View, e : var Event): bool =
    if e.buttonState == bsDown:
        if v.hidden: return false
        v.interceptEvents = false
        v.touchTarget = nil
        if v.subviews.len == 0:
            result = v.onTouchEv(e)
            if result:
                e.setTouchTarget(v)

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
                            e.setTouchTarget(s)
                            break

                if result and v.onListenTouchEv(e):
                    discard v.onTouchEv(e)
                if not result:
                    e.localPosition = localPosition
                    result = v.onTouchEv(e)
                    if result:
                        e.setTouchTarget(v)
    else:
        if numberOfActiveTouches() > 0:
            if v.subviews.len == 0:
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
                        var target = e.getTouchTarget()
                        if not target.isNil:
                            var localPosition = e.localPosition
                            e.localPosition = target.convertPointFromWindow(localPosition)
                            if v.onListenTouchEv(e):
                                discard v.onTouchEv(e)
                            result = target.onTouchEv(e)
                            e.localPosition = localPosition
                        else:
                            if not v.isMainWindow(e):
                                result = v.onTouchEv(e)

            v.window.handleMouseOverEvent(e)
        else:
            if v.isMainWindow(e):
                v.handleMouseOverEvent(e)

    if e.buttonState == bsUp:
        if v.isMainWindow(e) and numberOfActiveTouches() == 1:
            v.touchTarget = nil
            v.interceptEvents = false
        removeTouchTarget(e)

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

proc processKeyboardEvent*(v: View, e: var Event): bool =
    if v.hidden: return false

    case e.kind
    of etKeyboard:
        if e.buttonState == bsDown:
            result = v.onKeyDown(e)
        else:
            result = v.onKeyUp(e)
    of etTextInput:
        result = v.onTextInput(e.text)
    else:
        discard
