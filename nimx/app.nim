
import window
import event
import window_event_handling


type EventFilterControl* = enum
    efcContinue
    efcBreak

type EventFilter* = proc(evt: var Event, control: var EventFilterControl): bool

type Application* = ref object of RootObj
    windows : seq[Window]
    eventFilterStack : seq[EventFilter]

proc pushEventFilter*(a: Application, f: EventFilter) = a.eventFilterStack.add(f)
proc popEventFilter(a: Application) = discard a.eventFilterStack.pop()

proc newApplication(): Application =
    result.new()
    result.windows = @[]
    result.eventFilterStack = @[]
    let a = result
    result.pushEventFilter do(e: var Event, control: var EventFilterControl) -> bool:
        if not e.window.isNil:
            result = e.window.handleEvent(e)
        elif e.kind == etAppWillEnterBackground:
            for w in a.windows: w.enableAnimation(false)
        elif e.kind == etAppWillEnterForeground:
            for w in a.windows: w.enableAnimation(true)

var mainApp : Application

proc mainApplication*(): Application =
    if mainApp.isNil:
        mainApp = newApplication()
    result = mainApp

proc addWindow*(a: Application, w: Window) =
    a.windows.add(w)

proc handleEvent*(a: Application, e: var Event): bool =
    var control = efcContinue
    result = a.eventFilterStack[a.eventFilterStack.high](e, control)
    if control == efcBreak:
        a.popEventFilter()

proc drawWindows*(a: Application) =
    for w in a.windows:
        if w.needsDisplay:
            w.drawWindow()

proc runAnimations*(a: Application) =
    for w in a.windows: w.runAnimations()

