
import view
import event
export event
import system_logger


method onScroll*(v: View, e: var Event): bool {.base.} = discard
method onKeyDown*(v: View, e: var Event): bool {.base.} = discard
method onKeyUp*(v: View, e: var Event): bool {.base.} = discard
method onTextInput*(v: View, s: string): bool {.base.} = discard

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

method handleMouseEvent*(v: View, e: var Event): bool {.base, deprecated.} = discard
method onTouchGesEvent*(d: GestureDetector, e: var Event) : bool {.base, deprecated.} = discard
method onTouchEvent*(v: View, e: var Event): bool {.base, deprecated.} = discard
proc recursiveHandleMouseEvent*(v: View, e: var Event): bool {.deprecated.} = discard
proc handleTouchEvent*(v: View, e : var Event): bool {.deprecated.} = discard
