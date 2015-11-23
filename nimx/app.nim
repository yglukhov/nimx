import sequtils

import window
import event
import window_event_handling


type EventFilterControl* = enum
    efcContinue
    efcBreak

type EventFilter* = proc(evt: var Event, control: var EventFilterControl): bool

type Application* = ref object of RootObj
    windows : seq[Window]
    eventFilters: seq[EventFilter]

proc pushEventFilter*(a: Application, f: EventFilter) = a.eventFilters.add(f)

proc newApplication(): Application =
    result.new()
    result.windows = @[]
    result.eventFilters = @[]

var mainApp : Application

proc mainApplication*(): Application =
    if mainApp.isNil:
        mainApp = newApplication()
    result = mainApp

proc addWindow*(a: Application, w: Window) =
    a.windows.add(w)

proc handleEvent*(a: Application, e: var Event): bool =
    var control = efcContinue
    var cleanupEventFilters = false
    for i in 0 ..< a.eventFilters.len:
        result = a.eventFilters[i](e, control)
        if control == efcBreak:
            a.eventFilters[i] = nil
            cleanupEventFilters = true
            control = efcContinue
        if result:
            break

    if cleanupEventFilters:
        a.eventFilters.keepItIf(not it.isNil)

    if not result:
        if not e.window.isNil:
            result = e.window.handleEvent(e)
        elif e.kind == etAppWillEnterBackground:
            for w in a.windows: w.enableAnimation(false)
        elif e.kind == etAppWillEnterForeground:
            for w in a.windows: w.enableAnimation(true)

proc drawWindows*(a: Application) =
    for w in a.windows:
        if w.needsDisplay:
            w.drawWindow()

proc runAnimations*(a: Application) =
    for w in a.windows: w.runAnimations()
