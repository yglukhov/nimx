import control
import context
import types
import logging
import event

export control

type Button = ref object of Control

proc newButton*(r: Rect): Button =
    result.new()
    result.init(r)

method draw(b: Button) =
    let c = currentContext()
    c.fillColor = newColor(1, 0, 0)
    c.drawRoundedRect(b.bounds, 5)

method onMouseDown(b: Button, e: var Event): bool =
    result = true

method onMouseUp(b: Button, e: var Event): bool =
    result = true
    b.sendAction(e)

