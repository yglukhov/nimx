
import view
import event


method onMouseDown*(v: View, e: var Event): bool = discard
method onMouseUp*(v: View, e: var Event): bool = discard
method onKeyDown*(v: View, e: var Event): bool = discard
method onKeyUp*(v: View, e: var Event): bool = discard
method onTextInput*(v: View, s: string): bool = discard

method handleMouseEvent*(v: View, e: var Event): bool =
    if e.isButtonDownEvent():
        result = v.onMouseDown(e)
    elif e.isButtonUpEvent():
        result = v.onMouseUp(e)

proc recursiveHandleMouseEvent*(v: View, e: var Event): bool =
    if e.localPosition.inRect(v.bounds):
        let localPosition = e.localPosition
        for s in v.subviews:
            e.localPosition = localPosition - s.frame.origin
            result = s.recursiveHandleMouseEvent(e)
            if result:
                break
        if not result:
            e.localPosition = localPosition
            result = v.handleMouseEvent(e)


