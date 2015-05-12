import control
import context
import types
import logging
import event
import font
import app
import view_event_handling

export control

type Button = ref object of Control
    title*: string
    state*: ButtonState

proc newButton*(r: Rect): Button =
    result.new()
    result.init(r)

method init(b: Button, frame: Rect) =
    procCall b.Control.init(frame)
    b.state = bsUp
    b.backgroundColor = whiteColor()

method draw(b: Button, r: Rect) =
    let c = currentContext()
    var textColor: Color
    if b.state == bsUp:
        c.fillColor = b.backgroundColor
        textColor = blackColor()
    else:
        c.fillColor = newColor(0.25, 0.5, 0.95)
        textColor = whiteColor()

    c.strokeWidth = 0
    c.drawRoundedRect(b.bounds, 5)
    if b.title != nil:
        c.fillColor = textColor
        let font = systemFont()
        var pt = centerInRect(font.sizeOfString(b.title), b.bounds)
        c.drawText(font, pt, b.title)

proc setState*(b: Button, s: ButtonState) =
    if b.state != s:
        b.state = s
        b.setNeedsDisplay()

method onMouseDown(b: Button, e: var Event): bool =
    result = true
    b.setState(bsDown)
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

method onMouseUp(b: Button, e: var Event): bool =
    result = true
    b.setState(bsUp)
    if e.localPosition.inRect(b.bounds):
        b.sendAction(e)

