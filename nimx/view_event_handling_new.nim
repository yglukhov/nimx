import view
import event
export event
import system_logger
import typetraits

method onGestEvent*(d: GestureDetector, e: var Event) : bool {.base.} = discard
method onScroll*(v: View, e: var Event): bool = discard

method name*(v: View): string {.base.} =
    result = "View"

method onTouchEv*(v: View, e: var Event): bool {.base.} =
    if not v.gestureDetectors.isNil:
        for d in v.gestureDetectors:
            let r = d.onGestEvent(e)
            result = result or r
    # if not result:
    if e.buttonState == bsUp:
        if v.acceptsFirstResponder:
            discard v.makeFirstResponder()

method onInterceptTouchEv*(v: View, e: var Event): bool {.base.} =
    discard

proc isMainWindow(v: View, e : var Event): bool =
    result = v == e.window

proc processTouchEvent*(v: View, e : var Event): bool

var pointers = 0

method onMouseIn*(v: View, e: var Event) {.base.} =
    discard

method onMouseOver*(v: View, e: var Event) {.base.} =
    discard

method onMouseOut*(v: View, e: var Event) {.base.} =
    discard

proc handleMouseOverEvent(v: View, e : var Event) =
    let localPosition = e.localPosition
    for vi in v.window.mouseOverListeners:
        let r = vi.convertRectoToWindow(vi.bounds)
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

proc processOnlyTouchEvents(v: View, e : var Event): bool =
    if e.buttonState == bsDown:
        if v.isMainWindow(e):
            pointers = pointers + 1
            assert(pointers > 0)
        if pointers == 1:
            v.interceptEvents = false
            v.touchTarget = nil
            if v.subviews.isNil or v.subviews.len == 0:
                result = v.onTouchEv(e)
            else:
                if v.onInterceptTouchEv(e):
                    v.interceptEvents = true
                    result = v.onTouchEv(e)
                else:
                    let localPosition = e.localPosition
                    for i in countdown(v.subviews.len - 1, 0):
                        let s = v.subviews[i]
                        e.localPosition = localPosition - s.frame.origin + s.bounds.origin
                        if e.localPosition.inRect(s.bounds):
                            result = s.processTouchEvent(e)
                            if result:
                                v.touchTarget = s
                                break
                    if not result:
                        e.localPosition = localPosition
                        result = v.onTouchEv(e)
    else:
        if pointers > 0:
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
                        if not v.touchTarget.isNil:
                            let target = v.touchTarget
                            var localPosition = e.localPosition
                            e.localPosition = localPosition - target.frame.origin + target.bounds.origin
                            result = target.processTouchEvent(e)
                            e.localPosition = localPosition
                        else:
                            if not v.isMainWindow(e):
                                result = v.onTouchEv(e)
        else:
            if v.isMainWindow(e):
                v.handleMouseOverEvent(e)
    if e.buttonState == bsUp:
        if v.isMainWindow(e):
            pointers = pointers - 1
            assert(pointers >= 0)
        if pointers == 0:
            v.touchTarget = nil
            v.interceptEvents = false

proc processMouseWheelPrivate(v: View, e : var Event): bool =
    let localPosition = e.localPosition
    for i in countdown(v.subviews.len - 1, 0):
        let s = v.subviews[i]
        e.localPosition = localPosition - s.frame.origin + s.bounds.origin
        if e.localPosition.inRect(s.bounds):
            result = s.processTouchEvent(e)
            if result:
                break
    if not result:
        e.localPosition = localPosition
        result = v.onScroll(e)

proc processTouchEvent*(v: View, e : var Event): bool =
    case e.kind
    of etScroll:
        result = processMouseWheelPrivate(v,e)
    else:
        result = processOnlyTouchEvents(v,e)
