import types
import unicode
import abstract_window
import view

import keyboard
export keyboard

type EventType* = enum
    etUnknown
    etMouse
    etTouch
    etScroll
    etKeyboard
    etWindowResized
    etTextInput
    etTextEditing
    etAppWillEnterBackground
    etAppWillEnterForeground

type ButtonState* = enum
    bsUnknown
    bsUp
    bsDown

type Event* = object
    timestamp*: uint32
    kind*: EventType
    pointerId*: int # raw touchId
    position*: Point
    localPosition*: Point
    offset*: Point
    keyCode*: VirtualKey
    buttonState*: ButtonState
    rune*: Rune
    repeat*: bool
    window*: Window
    text*: string
    modifiers*: ModifiersSet
    target*: View # for touch events
    id*: int # logic touchId

proc newEvent*(kind: EventType, position: Point = zeroPoint, keyCode: VirtualKey = VirtualKey.Unknown,
               buttonState: ButtonState = bsUnknown, pointerId : int = 0, timestamp : uint32 = 0): Event =
    result.kind = kind
    result.position = position
    result.localPosition = position
    result.keyCode = keyCode
    result.buttonState = buttonState
    result.pointerId = pointerId
    result.timestamp = timestamp

proc newUnknownEvent*(): Event = newEvent(etUnknown)

proc newMouseMoveEvent*(position: Point, tstamp : uint32): Event =
    newEvent(etMouse, position, VirtualKey.Unknown, bsUnknown, 0, tstamp)

proc newMouseMoveEvent*(position: Point): Event =
    newEvent(etMouse, position, VirtualKey.Unknown, bsUnknown, 0, 0)

proc newMouseButtonEvent*(position: Point, button: VirtualKey, state: ButtonState, tstamp : uint32): Event =
    newEvent(etMouse, position, button, state, 0, tstamp)

proc newMouseButtonEvent*(position: Point, button: VirtualKey, state: ButtonState): Event =
    newEvent(etMouse, position, button, state, 0, 0)

proc newTouchEvent*(position: Point, state: ButtonState, pointerId : int, tstamp : uint32): Event =
    newEvent(etTouch, position, VirtualKey.Unknown, state, pointerId, tstamp)

proc newMouseDownEvent*(position: Point, button: VirtualKey): Event =
    newMouseButtonEvent(position, button, bsDown,0)

proc newMouseUpEvent*(position: Point, button: VirtualKey): Event =
    newMouseButtonEvent(position, button, bsUp,0)

proc newKeyboardEvent*(keyCode: VirtualKey, buttonState: ButtonState, repeat: bool = false): Event =
    result = newEvent(etKeyboard, zeroPoint, keyCode, buttonState)
    result.repeat = repeat

proc isPointingEvent*(e: Event) : bool =
    result = e.pointerId == 0 and (e.kind == etMouse or e.kind == etTouch)
proc isButtonDownEvent*(e: Event): bool = e.buttonState == bsDown
proc isButtonUpEvent*(e: Event): bool = e.buttonState == bsUp

proc isMouseMoveEvent*(e: Event): bool = e.buttonState == bsUnknown and e.kind == etMouse

var activeTouches = 0

const nimxMaxTouches = 10
var activeTouchesSeq: array[nimxMaxTouches, Event]
var multiTouchEnabled* = false

proc initTouches()=
    for i in 0 ..< activeTouchesSeq.len:
        activeTouchesSeq[i].pointerId = -1
initTouches()

import logging

proc setLogicalId(e: var Event)=
    if e.buttonState == bsDown:
        e.id = -1
        for i, t in activeTouchesSeq:
            if t.pointerId == -1:
                e.id = i
                break
        doAssert(e.id >= 0, "Incorrect logical id in bsDown ")
    else:
        e.id = -1
        for t in activeTouchesSeq:
            if t.pointerId == e.pointerId:
                e.id = t.id
                e.target = t.target
                break

        when not defined(ios) and not defined(android):
            if e.id == -1 and e.buttonState == bsUnknown:
                for i, t in activeTouchesSeq:
                    if t.pointerId == -1:
                        e.id = i
                        break

        doAssert(e.id >= 0, "Incorrect logical id in " & $e.buttonState)

template numberOfActiveTouches*(): int = activeTouches

proc incrementActiveTouchesIfNeeded(e: Event) =
    if e.buttonState == bsDown:
        inc activeTouches
        assert(activeTouches > 0)

proc decrementActiveTouchesIfNeeded(e: Event) =
    if e.buttonState == bsUp:
        assert(activeTouches > 0)
        dec activeTouches

# Private proc. Should be called from application.handleEvent()
proc begunTouchProcessing*(e: var Event)=
    if (e.kind == etTouch or e.kind == etMouse):
        e.incrementActiveTouchesIfNeeded()

        e.setLogicalId()
        activeTouchesSeq[e.id] = e

# Private proc. Should be called from application.handleEvent()
proc endTouchProcessing*(e: var Event)=
    if (e.kind == etTouch or e.kind == etMouse):
        e.decrementActiveTouchesIfNeeded()

        if e.buttonState == bsUp:
            e.pointerId = -1

        activeTouchesSeq[e.id] = e
