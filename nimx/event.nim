import types
import unicode
import abstract_window

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

type Touch* = object
    position*: Point
    id*: int

type Event* = object
    timestamp*: uint32
    kind*: EventType
    pointerId*: int
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

template numberOfActiveTouches*(): int = activeTouches

proc incrementActiveTouchesIfNeeded*(e: Event) =
    # Private proc. Should be called from application.handleEvent()
    if (e.kind == etTouch or e.kind == etMouse) and e.buttonState == bsDown:
        inc activeTouches
        assert(activeTouches > 0)

proc decrementActiveTouchesIfNeeded*(e: Event) =
    # Private proc. Should be called from application.handleEvent()
    if (e.kind == etTouch or e.kind == etMouse) and e.buttonState == bsUp:
        assert(activeTouches > 0)
        dec activeTouches
