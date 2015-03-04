import types

type EventType = enum
    etMouse
    etScroll
    etKeyDown
    etKeyUp

type ButtonState* = enum
    bsUnknown
    bsUp
    bsDown

type KeyCode* = enum
    kcUnknown
    kcMouseButtonPrimary
    kcMouseButtonSecondary
    kcMouseButtonMiddle

type Event* = object
    kind*: EventType
    position*: Point
    localPosition*: Point
    button*: KeyCode
    buttonState*: ButtonState

proc newEvent(kind: EventType, position: Point, button: KeyCode, buttonState: ButtonState): Event =
    result.kind = kind
    result.position = position
    result.localPosition = position
    result.button = button
    result.buttonState = buttonState

proc newMouseMoveEvent*(position: Point): Event =
    newEvent(etMouse, position, kcUnknown, bsUnknown)

proc newMouseButtonEvent*(position: Point, button: KeyCode, state: ButtonState): Event =
    newEvent(etMouse, position, button, state)

proc newMouseDownEvent*(position: Point, button: KeyCode): Event =
    newMouseButtonEvent(position, button, bsDown)

proc newMouseUpEvent*(position: Point, button: KeyCode): Event =
    newMouseButtonEvent(position, button, bsUp)

proc isButtonDownEvent*(e: Event): bool = e.buttonState == bsDown
proc isButtonUpEvent*(e: Event): bool = e.buttonState == bsUp
