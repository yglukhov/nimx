import control
import context
import font
import types
import event
import window
import unistring
import unicode
import times


type TextField* = ref object of Control
    text*: string
    editable*: bool
    selectable*: bool

var cursorPos = 0
var cursorBlinkTime = 0.0
var cursorVisible = true

var cursorOffset : Coord

const leftMargin = 3.0

proc newTextField*(r: Rect): TextField =
    result.new()
    result.init(r)

method init*(t: TextField, r: Rect) =
    procCall t.Control.init(r)
    t.editable = true
    t.selectable = true

proc isEditing*(t: TextField): bool =
    t.editable and t.isFirstResponder

proc drawCursorWithRect(r: Rect) =
    let curTime = epochTime()
    if curTime - cursorBlinkTime > 0.5:
        cursorBlinkTime = curTime
        cursorVisible = not cursorVisible
    if cursorVisible:
        let c = currentContext()
        c.fillColor = blackColor()
        c.drawRect(r)

proc bumpCursorVisibility() =
    cursorVisible = true
    cursorBlinkTime = epochTime()

method draw*(t: TextField, r: Rect) =
    let c = currentContext()
    c.fillColor = whiteColor()
    c.strokeColor = newGrayColor(0.74)
    c.drawRect(t.bounds)
    let font = systemFont()

    var textY = (t.bounds.height - font.size) / 2

    if t.text != nil:
        var pt = newPoint(leftMargin, textY)
        c.fillColor = blackColor()
        c.drawText(systemFont(), pt, t.text)

    if t.isEditing:
        drawCursorWithRect(newRect(leftMargin + cursorOffset, textY + 3, 2, font.size))

method onMouseDown*(t: TextField, e: var Event): bool =
    if t.editable:
        result = t.makeFirstResponder()
        t.window.startTextInput(t.convertRectoToWindow(t.bounds))
        var pt = e.localPosition
        pt.x += leftMargin
        if t.text.isNil:
            cursorPos = 0
            cursorOffset = 0
        else:
            systemFont().getClosestCursorPositionToPointInString(t.text, pt, cursorPos, cursorOffset)
        bumpCursorVisibility()

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
            bumpCursorVisibility()
        elif e.keyCode == K_DELETE and not t.text.isNil and cursorPos < t.text.runeLen:
            t.text.uniDelete(cursorPos, cursorPos)
            bumpCursorVisibility()
        elif e.keyCode == K_LEFT:
            dec cursorPos
            if cursorPos < 0: cursorPos = 0
            t.updateCursorOffset()
            bumpCursorVisibility()
        elif e.keyCode == K_RIGHT:
            inc cursorPos
            let textLen = t.text.runeLen
            if cursorPos > textLen: cursorPos = textLen
            t.updateCursorOffset()
            bumpCursorVisibility()

method onTextInput*(t: TextField, s: string): bool =
    result = true
    if t.text.isNil: t.text = ""
    t.text.insert(cursorPos, s)
    cursorPos += s.runeLen
    t.updateCursorOffset()

