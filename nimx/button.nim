import control
import context
import types
import logging
import event
import font

export control

type Button = ref object of Control
    title*: string

proc newButton*(r: Rect): Button =
    result.new()
    result.init(r)

method draw(b: Button) =
    let c = currentContext()
    c.fillColor = newColor(1, 0, 0)
    c.drawRoundedRect(b.bounds, 5)
    if b.title != nil:
        c.fillColor = newColor(0, 0, 0)
        let font = systemFont()
        var pt = centerInRect(font.sizeOfString(b.title), b.bounds)
        c.drawText(font, pt, b.title)

method onMouseDown(b: Button, e: var Event): bool =
    result = true

method onMouseUp(b: Button, e: var Event): bool =
    result = true
    b.sendAction(e)

