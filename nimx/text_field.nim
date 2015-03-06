import control
import context
import font
import types

type TextField = ref object of Control
    text*: string

proc newTextField*(r: Rect): TextField =
    result.new()
    result.init(r)

method draw*(t: TextField, r: Rect) =
    let c = currentContext()
    c.fillColor = whiteColor()
    c.strokeColor = newGrayColor(0.74)
    c.drawRect(t.bounds)
    if t.text != nil:
        let font = systemFont()
        var pt = newPoint(3, (t.bounds.height - font.size) / 2)
        c.fillColor = blackColor()
        c.drawText(systemFont(), pt, t.text)

