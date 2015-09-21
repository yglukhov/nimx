
import view
import event
export event

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
