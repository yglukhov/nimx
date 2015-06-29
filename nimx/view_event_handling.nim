
import view
import event
export event

method onMouseDown*(v: View, e: var Event): bool =
    if v.acceptsFirstResponder:
        result = v.makeFirstResponder()

method onMouseUp*(v: View, e: var Event): bool = discard
method onScroll*(v: View, e: var Event): bool = discard
method onKeyDown*(v: View, e: var Event): bool = discard
method onKeyUp*(v: View, e: var Event): bool = discard
method onTextInput*(v: View, s: string): bool = discard

method handleMouseEvent*(v: View, e: var Event): bool =
    if e.isButtonDownEvent():
        result = v.onMouseDown(e)
    elif e.isButtonUpEvent():
        result = v.onMouseUp(e)
    elif e.kind == etScroll:
        result = v.onScroll(e)

proc recursiveHandleMouseEvent*(v: View, e: var Event): bool =
    if e.localPosition.inRect(v.bounds):
        let localPosition = e.localPosition
        for s in v.subviews:
            e.localPosition = localPosition - s.frame.origin + s.bounds.origin
            result = s.recursiveHandleMouseEvent(e)
            if result:
                break
        if not result:
            e.localPosition = localPosition
            result = v.handleMouseEvent(e)
