import types
import window
import event
import view_event_handling

proc canPassEventToFirstResponder(w: Window): bool =
    w.firstResponder != nil and w.firstResponder != w

method onKeyDown*(w: Window, e: var Event): bool =
    if w.canPassEventToFirstResponder:
        result = w.firstResponder.onKeyDown(e)

method onKeyUp*(w: Window, e: var Event): bool =
    if w.canPassEventToFirstResponder:
        result = w.firstResponder.onKeyUp(e)

method onTextInput*(w: Window, s: string): bool =
    if w.canPassEventToFirstResponder:
        result = w.firstResponder.onTextInput(s)

method handleEvent*(w: Window, e: var Event): bool =
    case e.kind:
        of etMouse, etScroll:
            result = w.recursiveHandleMouseEvent(e)
        of etKeyboard:
            if e.buttonState == bsDown:
                result = w.onKeyDown(e)
            else:
                result = w.onKeyUp(e)
        of etTextInput:
            result = w.onTextInput(e.text)
        of etWindowResized:
            result = true
            w.onResize(newSize(e.position.x, e.position.y))
            w.drawWindow()
        else:
            result = false

