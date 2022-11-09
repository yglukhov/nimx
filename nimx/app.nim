import sequtils

import abstract_window
import event
import window_event_handling
import logging

type EventFilterControl* = enum
    efcContinue
    efcBreak

type EventFilter* = proc(evt: var Event, control: var EventFilterControl): bool {.gcsafe.}

type Application* = ref object of RootObj
    windows : seq[Window]
    eventFilters: seq[EventFilter]
    inputState: set[VirtualKey]
    modifiers: ModifiersSet

proc pushEventFilter*(a: Application, f: EventFilter) = a.eventFilters.add(f)

proc newApplication(): Application =
    result.new()
    result.windows = @[]
    result.eventFilters = @[]
    result.inputState = {}

var mainApp {.threadvar.}: Application

proc mainApplication*(): Application =
    if mainApp.isNil:
        mainApp = newApplication()
    result = mainApp

proc addWindow*(a: Application, w: Window) =
    a.windows.add(w)

proc removeWindow*(a: Application, w: Window) =
    let i = a.windows.find(w)
    if i >= 0: a.windows.delete(i)

proc handleEvent*(a: Application, e: var Event): bool =
    if numberOfActiveTouches() == 0 and e.kind == etMouse and e.buttonState == bsUp:
        # There may be cases when mouse up is not paired with mouse down.
        # This behavior may be observed in Web and native platforms, when clicking on canvas in menu-modal
        # mode. We just ignore such events.
        warn "Mouse up event ignored"
        return false

    if e.kind == etMouse and e.buttonState == bsDown and e.keyCode in a.inputState:
        # There may be cases when mouse down is not paired with mouse up.
        # This behavior may be observed in Web and native platforms
        # We just send mouse bsUp fake event

        var fakeEvent = newMouseButtonEvent(e.position, e.keyCode, bsUp, e.timestamp)
        fakeEvent.window = e.window
        discard a.handleEvent(fakeEvent)

    beginTouchProcessing(e)

    if e.kind == etMouse or e.kind == etTouch or e.kind == etKeyboard:
        let kc = e.keyCode
        let isModifier = kc.isModifier
        if e.buttonState == bsDown:
            if isModifier:
                a.modifiers.incl(kc)
            a.inputState.incl(kc)
        else:
            if isModifier:
                a.modifiers.excl(kc)
            a.inputState.excl(kc)

    e.modifiers = a.modifiers

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
        elif e.kind in { etAppWillEnterBackground, etAppDidEnterBackground }:
            for w in a.windows: w.enableAnimation(false)
        elif e.kind in { etAppWillEnterForeground, etAppDidEnterForeground }:
            for w in a.windows: w.enableAnimation(true)

    endTouchProcessing(e)

proc drawWindows*(a: Application) =
    for w in a.windows:
        if w.needsLayout:
            w.updateWindowLayout()

        if w.needsDisplay:
            w.drawWindow()

proc runAnimations*(a: Application) =
    for w in a.windows: w.runAnimations()

proc keyWindow*(a: Application): Window =
    if a.windows.len > 0:
        result = a.windows[^1]
