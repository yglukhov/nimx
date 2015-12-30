
import view
import event
export event
import system_logger



method onMouseDown*(v: View, e: var Event): bool {.base.} =
    if v.acceptsFirstResponder:
        result = v.makeFirstResponder()

method onMouseUp*(v: View, e: var Event): bool {.base.} = discard
method onScroll*(v: View, e: var Event): bool {.base.} = discard
method onKeyDown*(v: View, e: var Event): bool {.base.} = discard
method onKeyUp*(v: View, e: var Event): bool {.base.} = discard
method onTextInput*(v: View, s: string): bool {.base.} = discard

method handleMouseEvent*(v: View, e: var Event): bool {.base.} =
    if e.isButtonDownEvent():
        result = v.onMouseDown(e)
    elif e.isButtonUpEvent():
        result = v.onMouseUp(e)
    elif e.kind == etScroll:
        result = v.onScroll(e)

method onTouchGesEvent*(d: GestureDetector, e: var Event) : bool {.base.} = discard

method onTouchEvent*(v: View, e: var Event): bool {.base.} =
    result = false
    for i in v.gestureDetectors:
        let a = i.onTouchGesEvent(e)
        result = result or a
    if v.gestureDetectors.len < 1:
        result = v.handleMouseEvent(e)

proc recursiveHandleMouseEvent*(v: View, e: var Event): bool =
    if e.localPosition.inRect(v.bounds):
        let localPosition = e.localPosition
        for i in countdown(v.subviews.len - 1, 0):
            let s = v.subviews[i]
            e.localPosition = localPosition - s.frame.origin + s.bounds.origin
            result = s.recursiveHandleMouseEvent(e)
            if result:
                break
        if not result:
            e.localPosition = localPosition
            result = v.handleMouseEvent(e)

proc handleTouchEvent*(v: View, e : var Event): bool =
    if e.buttonState == bsDown:
        if e.localPosition.inRect(v.bounds):
            let localPosition = e.localPosition
            for i in countdown(v.subviews.len - 1, 0):
                let s = v.subviews[i]
                e.localPosition = localPosition - s.frame.origin + s.bounds.origin
                result = s.handleTouchEvent(e)
                if result:
                    break
            if not result:
                e.localPosition = localPosition
                result = v.onTouchEvent(e)
