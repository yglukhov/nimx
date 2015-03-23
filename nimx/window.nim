
import view
import sets
import hashes

export view

# Window type is defined in view module


#TODO: Window size has two notions. Think about it.

method init*(w: Window, frame: Rect) =
    procCall w.View.init(frame)
    w.window = w

method onResize*(w: Window, newSize: Size) =
    procCall w.View.setFrameSize(newSize)

method drawWindow*(w: Window) =
    w.recursiveDrawSubviews()

proc hash(w: Window): THash =
    return cast[THash](cast[pointer](w))

var windowsRegisteredForOutsideMouseEventsSet = initSet[Window]()

method registerForMouseEventsOutside*(w: Window) =
    windowsRegisteredForOutsideMouseEventsSet.incl(w)

method unregisterForMouseEventsOutside*(w: Window) =
    windowsRegisteredForOutsideMouseEventsSet.excl(w)

method enableAnimation*(w: Window, flag: bool) = discard

proc windowsRegisteredForOutsideMouseEvents*(): auto = windowsRegisteredForOutsideMouseEventsSet

method startTextInput*(w: Window) = discard
method stopTextInput*(w: Window) = discard

