
import view
import sets
import hashes
import event

export view

# Window type is defined in view module


#TODO: Window size has two notions. Think about it.

method init*(w: Window, frame: Rect) =
    procCall w.View.init(frame)
    w.window = w

method onResize*(w: Window, newSize: Size) =
    procCall w.View.setFrameSize(newSize)

proc hash(w: Window): THash =
    return cast[THash](cast[pointer](w))

var windowsRegisteredForOutsideMouseEventsSet = initSet[Window]()

method registerForMouseEventsOutside*(w: Window) =
    windowsRegisteredForOutsideMouseEventsSet.incl(w)

method unregisterForMouseEventsOutside*(w: Window) =
    windowsRegisteredForOutsideMouseEventsSet.excl(w)

proc windowsRegisteredForOutsideMouseEvents*(): auto = windowsRegisteredForOutsideMouseEventsSet

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

method startTextInput*(w: Window) = discard
method stopTextInput*(w: Window) = discard

