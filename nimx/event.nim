import types
import unicode
import abstract_window

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

type KeyCode* = enum
    kcUnknown
    kcMouseButtonPrimary
    kcMouseButtonSecondary
    kcMouseButtonMiddle

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
    fButton: cint # SDL Keycode for keyboard events and KeyCode for mouse events
    buttonState*: ButtonState
    rune*: Rune
    repeat*: bool
    window*: Window
    text*: string

proc button*(e: Event): KeyCode = cast[KeyCode](e.fButton)
proc `button=`*(e: var Event, b: KeyCode) = e.fButton = cast[cint](b)

proc keyCode*(e: Event): cint = e.fButton
proc `keyCode=`*(e: var Event, c: cint) = e.fButton = c

proc newEvent*(kind: EventType, position: Point = zeroPoint, button: KeyCode = kcUnknown,
               buttonState: ButtonState = bsUnknown, pointerId : int = 0, timestamp : uint32 = 0): Event =
    result.kind = kind
    result.position = position
    result.localPosition = position
    result.button = button
    result.buttonState = buttonState
    result.pointerId = pointerId
    result.timestamp = timestamp

proc newUnknownEvent*(): Event = newEvent(etUnknown)

proc newMouseMoveEvent*(position: Point, tstamp : uint32): Event =
    newEvent(etMouse, position, kcUnknown, bsUnknown, 0, tstamp)

proc newMouseButtonEvent*(position: Point, button: KeyCode, state: ButtonState, tstamp : uint32): Event =
    newEvent(etMouse, position, button, state, 0, tstamp)

proc newTouchEvent*(position: Point, state: ButtonState, pointerId : int, tstamp : uint32): Event =
    newEvent(etTouch, position, kcUnknown, state, pointerId, tstamp)

proc newMouseDownEvent*(position: Point, button: KeyCode): Event =
    newMouseButtonEvent(position, button, bsDown,0)

proc newMouseUpEvent*(position: Point, button: KeyCode): Event =
    newMouseButtonEvent(position, button, bsUp,0)

proc newKeyboardEvent*(keyCode: cint, buttonState: ButtonState, repeat: bool = false): Event =
    result = newEvent(etKeyboard, zeroPoint, kcUnknown, buttonState)
    result.keyCode = keyCode
    result.repeat = repeat

proc isPointingEvent*(e: Event) : bool =
    result = e.pointerId == 0 and (e.kind == etMouse or e.kind == etTouch)
proc isButtonDownEvent*(e: Event): bool = e.buttonState == bsDown
proc isButtonUpEvent*(e: Event): bool = e.buttonState == bsUp

proc isMouseMoveEvent*(e: Event): bool = e.buttonState == bsUnknown and e.kind == etMouse
