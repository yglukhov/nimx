import types
import abstract_window
import event
import view_event_handling
import view_event_handling_new
import sets
import system_logger

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

var keyboardState: set[VirtualKey] = {}

proc alsoPressed*(vk: VirtualKey): bool =
    return vk in keyboardState

method handleEvent*(w: Window, e: var Event): bool {.base.} =
    case e.kind:
        of etScroll:
            result = w.processMouseWheelEvent(e)
        of etMouse, etTouch:
            result = w.processTouchEvent(e)
        of etKeyboard:
            if e.buttonState == bsDown:
                keyboardState.incl(e.keyCode)
                result = w.onKeyDown(e)
            else:
                result = w.onKeyUp(e)
                keyboardState.excl(e.keyCode)
        of etTextInput:
            result = w.onTextInput(e.text)
        of etWindowResized:
            result = true
            w.onResize(newSize(e.position.x, e.position.y))
            w.drawWindow()
        else:
            result = false
