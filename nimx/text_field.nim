import control
import context
import font
import types
import event
import abstract_window
import unistring
import unicode
import timer
import table_view_cell

export control

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

proc newTextField*(parent: View = nil, position: Point = newPoint(0, 0), size: Size = newSize(100, 20), text: string = ""): TextField =
    result = newTextField(newRect(position.x, position.y, size.width, size.height))
    result.editable = true
    result.text = text
    if not isNil(parent):
        parent.addSubview(result)

proc newLabel*(r: Rect): TextField =
    result = newTextField(r)
    result.editable = false

proc newLabel*(parent: View = nil, position: Point = newPoint(0, 0), size: Size = newSize(100, 20), text: string = "label"): TextField =
    result = newLabel(newRect(position.x, position.y, size.width, size.height))
    result.editable = false
    result.text = text
    if not isNil(parent):
        parent.addSubview(result)

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
        c.strokeWidth = 0
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
        c.drawRect(t.bounds)

    let font = systemFont()

    var textY = (t.bounds.height - font.size) / 2

    if t.text != nil:
        var pt = newPoint(leftMargin, textY)
        let cell = t.enclosingTableViewCell()
        if not cell.isNil and cell.selected:
            c.fillColor = whiteColor()
        else:
            c.fillColor = blackColor()
        c.drawText(systemFont(), pt, t.text)

    if t.isEditing:
        t.drawFocusRing()
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

method onTouchEv(t: TextField, e: var Event): bool =
    result = false
    case e.buttonState
    of bsDown:
        if t.editable:
            result = t.makeFirstResponder()
            var pt = e.localPosition
            pt.x += leftMargin
            if t.text.isNil:
                cursorPos = 0
                cursorOffset = 0
            else:
                systemFont().getClosestCursorPositionToPointInString(t.text, pt, cursorPos, cursorOffset)
    of bsUp:
        result = false
    else: discard

proc updateCursorOffset(t: TextField) =
    cursorOffset = systemFont().cursorOffsetForPositionInString(t.text, cursorPos)

method onKeyDown*(t: TextField, e: var Event): bool =
    if e.keyCode == VirtualKey.Backspace and cursorPos > 0:
        result = true
        t.text.uniDelete(cursorPos - 1, cursorPos - 1)
        dec cursorPos
        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Delete and not t.text.isNil and cursorPos < t.text.runeLen:
        t.text.uniDelete(cursorPos, cursorPos)
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Left:
        dec cursorPos
        if cursorPos < 0: cursorPos = 0
        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Right:
        inc cursorPos
        let textLen = t.text.runeLen
        if cursorPos > textLen: cursorPos = textLen
        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Return:
        t.sendAction()

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
    v.sendAction()

method viewDidBecomeFirstResponder*(t: TextField) =
    t.window.startTextInput(t.convertRectoToWindow(t.bounds))
    cursorPos = if t.text.isNil: 0 else: t.text.len
    t.updateCursorOffset()
    t.bumpCursorVisibility()
