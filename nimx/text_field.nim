import control
import context
import font
import types
import event
import window

type TextField = ref object of Control
    text*: string
    editable*: bool
    selectable*: bool
    cursorPos: int

proc newTextField*(r: Rect): TextField =
    result.new()
    result.init(r)

method draw*(t: TextField, r: Rect) =
    let c = currentContext()
    c.fillColor = whiteColor()
    c.strokeColor = newGrayColor(0.74)
    c.drawRect(t.bounds)
    var cursorOffset = 0.0
    let font = systemFont()

    var textY = (t.bounds.height - font.size) / 2

    if t.text != nil:
        var textSize = font.sizeOfString(t.text)
        var pt = newPoint(3, textY)
        c.fillColor = blackColor()
        c.drawText(systemFont(), pt, t.text)
        t.cursorPos = min(t.text.len - 1, t.cursorPos)
        cursorOffset = font.sizeOfString(t.text[0 .. t.cursorPos]).width

    c.fillColor = blackColor()
    c.drawRect(newRect(cursorOffset, textY, 2, font.size))


method onMouseDown*(t: TextField, e: var Event): bool =
    result = t.makeFirstResponder()
    t.window.startTextInput()

method onKeyDown*(t: TextField, e: var Event): bool =
    discard

method onTextInput*(t: TextField, s: string): bool =
    result = true
    if t.text == nil: t.text = ""
    t.text &= s

