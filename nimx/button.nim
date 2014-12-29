import control
import context
import types
import logging

type Button = ref object of Control

proc newButton*(r: Rect): Button =
    result.new()
    result.init(r)

method draw(b: Button) =
    let c = currentContext()
    c.fillColor = newColor(1, 0, 0)
    c.drawRect(b.bounds)

