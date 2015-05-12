import control
import context
import font
import types
import event
import window
import unistring
import unicode
import timer


type TextField* = ref object of Control
    text*: string
    editable*: bool
    selectable*: bool

var cursorPos = 0
var cursorVisible = true
var cursorUpdateTimer : Timer

var cursorOffset : Coord

const leftMargin = 3.0

proc newTextField*(r: Rect): TextField =
    result.new()
    result.init(r)

proc newLabel*(r: Rect): TextField =
    result = newTextField(r)
    result.editable = false

method init*(t: TextField, r: Rect) =
    procCall t.Control.init(r)
    t.editable = true
    t.selectable = true

proc isEditing*(t: TextField): bool =
    t.editable and t.isFirstResponder

proc drawCursorWithRect(r: Rect) =
    if cursorVisible:
        let c = currentContext()
        c.fillColor = blackColor()
        c.drawRect(r)

proc bumpCursorVisibility(t: TextField) =
    cursorVisible = true
    cursorUpdateTimer.clear()
    t.setNeedsDisplay()

    let p = proc() =
        cursorVisible = not cursorVisible
        t.setNeedsDisplay()

    cursorUpdateTimer = setInterval(0.5, p)

method draw*(t: TextField, r: Rect) =
    let c = currentContext()
    if t.editable:
        c.fillColor = whiteColor()
        c.strokeColor = newGrayColor(0.74)
        c.strokeWidth = 1.0
        c.drawRoundedRect(t.bounds, 0)

    let font = systemFont()

    var textY = (t.bounds.height - font.size) / 2

    if t.text != nil:
        var pt = newPoint(leftMargin, textY)
        c.fillColor = blackColor()
        c.drawText(systemFont(), pt, t.text)

    if t.isEditing:
        c.fillColor = clearColor()
        c.strokeColor = newColor(0.59, 0.76, 0.95, 0.9)
        c.strokeWidth = 3
        c.drawRoundedRect(t.bounds.inset(-1, -1), 0)

        drawCursorWithRect(newRect(leftMargin + cursorOffset, textY + 3, 2, font.size))

method onMouseDown*(t: TextField, e: var Event): bool =
    if t.editable:
        result = t.makeFirstResponder()
        var pt = e.localPosition
        pt.x += leftMargin
        if t.text.isNil:
            cursorPos = 0
            cursorOffset = 0
        else:
            systemFont().getClosestCursorPositionToPointInString(t.text, pt, cursorPos, cursorOffset)

proc updateCursorOffset(t: TextField) =
    cursorOffset = systemFont().cursorOffsetForPositionInString(t.text, cursorPos)

when not defined js:
    import sdl2 except Event

method onKeyDown*(t: TextField, e: var Event): bool =
    when not defined js:
        if e.keyCode == K_BACKSPACE and cursorPos > 0:
            result = true
            t.text.uniDelete(cursorPos - 1, cursorPos - 1)
            dec cursorPos
            t.updateCursorOffset()
            t.bumpCursorVisibility()
        elif e.keyCode == K_DELETE and not t.text.isNil and cursorPos < t.text.runeLen:
            t.text.uniDelete(cursorPos, cursorPos)
            t.bumpCursorVisibility()
        elif e.keyCode == K_LEFT:
            dec cursorPos
            if cursorPos < 0: cursorPos = 0
            t.updateCursorOffset()
            t.bumpCursorVisibility()
        elif e.keyCode == K_RIGHT:
            inc cursorPos
            let textLen = t.text.runeLen
            if cursorPos > textLen: cursorPos = textLen
            t.updateCursorOffset()
            t.bumpCursorVisibility()

method onTextInput*(t: TextField, s: string): bool =
    result = true
    if t.text.isNil: t.text = ""
    t.text.insert(cursorPos, s)
    cursorPos += s.runeLen
    t.updateCursorOffset()
    t.bumpCursorVisibility()

method viewShouldResignFirstResponder*(v: TextField, newFirstResponder: View): bool =
    result = true
    cursorUpdateTimer.clear()
    cursorVisible = false

method viewDidBecomeFirstResponder*(t: TextField) =
    t.window.startTextInput(t.convertRectoToWindow(t.bounds))
    cursorPos = if t.text.isNil: 0 else: t.text.len
    t.updateCursorOffset()
    t.bumpCursorVisibility()

