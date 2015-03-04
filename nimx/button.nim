import control
import context
import types
import logging
import event
import font

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

method draw(b: Button, r: Rect) =
    let c = currentContext()
    var textColor: Color
    if b.state == bsUp:
        c.fillColor = newColor(1, 1, 1)
        textColor = newColor(0, 0, 0)
    else:
        c.fillColor = newColor(0.25, 0.5, 0.95)
        textColor = newColor(1, 1, 1)

    c.drawRoundedRect(b.bounds, 5)
    if b.title != nil:
        c.fillColor = textColor
        let font = systemFont()
        var pt = centerInRect(font.sizeOfString(b.title), b.bounds)
        c.drawText(font, pt, b.title)

method onMouseDown(b: Button, e: var Event): bool =
    result = true
    b.state = bsDown

method onMouseUp(b: Button, e: var Event): bool =
    result = true
    b.state = bsUp
    b.sendAction(e)

