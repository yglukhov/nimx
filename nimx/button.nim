import control
import context
import types
import system_logger
import event
import font
import app
import view_event_handling

export control

const selectionColor = newColor(0.40, 0.59, 0.95)

type ButtonStyle* = enum
    bsRegular
    bsCheckbox
    bsRadiobox

type ButtonBehavior = enum
    bbMomentaryLight
    bbToggle

type Button = ref object of Control
    title*: string
    state*: ButtonState
    value*: int8
    style*: ButtonStyle
    behavior*: ButtonBehavior

proc newButton*(r: Rect): Button =
    result.new()
    result.init(r)

proc newCheckbox*(r: Rect): Button =
    result = newButton(r)
    result.style = bsCheckbox
    result.behavior = bbToggle

proc newRadiobox*(r: Rect): Button =
    result = newButton(r)
    result.style = bsRadiobox
    result.behavior = bbToggle

method init(b: Button, frame: Rect) =
    procCall b.Control.init(frame)
    b.state = bsUp
    b.backgroundColor = whiteColor()

proc drawTitle(b: Button, xOffset: Coord) =
    if b.title != nil:
        let c = currentContext()
        c.fillColor = if b.state == bsDown and b.style == bsRegular:
                whiteColor()
            else:
                blackColor()

        let font = systemFont()
        var titleRect = b.bounds
        var pt = centerInRect(font.sizeOfString(b.title), titleRect)
        if pt.x < xOffset: pt.x = xOffset
        c.drawText(font, pt, b.title)

proc drawRegularStyle(b: Button, r: Rect) {.inline.} =
    let c = currentContext()

    if b.state == bsUp:
        c.fillColor = b.backgroundColor
        c.strokeColor = newGrayColor(0.78)
    else:
        c.fillColor = selectionColor
        c.strokeColor = newColor(0.18, 0.50, 0.98)

    c.strokeWidth = 1
    c.drawRoundedRect(b.bounds, 5)
    b.drawTitle(0)


proc drawCheckboxStyle(b: Button, r: Rect) =
    let bezelRect = newRect(0, 0, b.bounds.height, b.bounds.height)
    let c = currentContext()
    c.fillColor = whiteColor()
    c.strokeColor = newGrayColor(0.78)
    c.strokeWidth = 1
    c.drawRoundedRect(bezelRect, 2)

    if b.value != 0:
        let insetVal = bezelRect.height * 0.18
        let checkMarkRect = bezelRect.inset(insetVal, insetVal)
        c.strokeWidth = 0
        c.fillColor = selectionColor
        c.drawRoundedRect(checkMarkRect, 1)
    b.drawTitle(bezelRect.width + 1)

proc drawRadioboxStyle(b: Button, r: Rect) =
    let bezelRect = newRect(0, 0, b.bounds.height, b.bounds.height)
    let c = currentContext()
    c.fillColor = whiteColor()
    c.strokeColor = newGrayColor(0.78)
    c.strokeWidth = 1
    c.drawRoundedRect(bezelRect, bezelRect.height / 2)

    if b.value != 0:
        let insetVal = bezelRect.height * 0.18
        let checkMarkRect = bezelRect.inset(insetVal, insetVal)
        c.strokeWidth = 0
        c.fillColor = selectionColor
        c.drawRoundedRect(checkMarkRect, checkMarkRect.height / 2)
    b.drawTitle(bezelRect.width + 1)

method draw(b: Button, r: Rect) =
    if b.style == bsRadiobox:
        b.drawRadioboxStyle(r)
    elif b.style == bsCheckbox:
        b.drawCheckboxStyle(r)
    else:
        b.drawRegularStyle(r)

proc setState*(b: Button, s: ButtonState) =
    if b.state != s:
        b.state = s
        b.setNeedsDisplay()

method onMouseDown(b: Button, e: var Event): bool =
    result = true
    b.setState(bsDown)
    if b.behavior == bbMomentaryLight:
        b.value = 1

    mainApplication().pushEventFilter do(e: var Event, c: var EventFilterControl) -> bool:
        result = true
        if e.kind == etMouse:
            e.localPosition = b.convertPointFromWindow(e.position)
            if e.isButtonUpEvent():
                c = efcBreak
                result = b.onMouseUp(e)
            elif e.isMouseMoveEvent():
                if e.localPosition.inRect(b.bounds):
                    b.setState(bsDown)
                else:
                    b.setState(bsUp)

template toggleValue(v: int8): int8 =
    if v == 0:
        1
    else:
        0

method onMouseUp(b: Button, e: var Event): bool =
    result = true
    b.setState(bsUp)
    if b.behavior == bbMomentaryLight:
        b.value = 0

    if e.localPosition.inRect(b.bounds):
        if b.behavior == bbToggle:
            b.value = toggleValue(b.value)
        b.sendAction(e)
