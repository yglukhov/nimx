
import view
import sets
import hashes

type Window* = ref object of View

#TODO: Window size has to notions. Think about it.

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

