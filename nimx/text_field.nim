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
import window_event_handling

export control

type TextField* = ref object of Control
    text*: string
    editable*: bool
    textColor*: Color

    textSelection: tuple[selected: bool, inselection: bool, startIndex: int, endIndex: int]

var cursorPos = 0
var cursorVisible = true
var cursorUpdateTimer : Timer

var cursorOffset : Coord

const leftMargin = 3.0

proc newTextField*(r: Rect): TextField =
    result.new()
    result.init(r)
    result.textColor = newGrayColor(0.0)

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
    t.textSelection = (false, false, -1, -1)

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

    if t.textSelection.selected:
        if t.textSelection.startIndex != -1 and t.textSelection.endIndex != -1:
            c.fillColor = newColor(0.0, 0.0, 1.0, 0.5)
            let
                startPoint = font.cursorOffsetForPositionInString(t.text, t.textSelection.startIndex)
                endPoint = font.cursorOffsetForPositionInString(t.text, t.textSelection.endIndex)

            if startPoint < endPoint:
                c.drawRect(newRect(leftMargin + startPoint, 2, endPoint - startPoint, font.size))
            else:
                c.drawRect(newRect(leftMargin + endPoint, 2, startPoint - endPoint, font.size))

            t.setNeedsDisplay()

    if t.text != nil:
        var pt = newPoint(leftMargin, textY)
        let cell = t.enclosingTableViewCell()
        if not cell.isNil and cell.selected:
            c.fillColor = whiteColor()
        else:
            c.fillColor = t.textColor
        c.drawText(systemFont(), pt, t.text)

    if t.isEditing:
        t.drawFocusRing()
        drawCursorWithRect(newRect(leftMargin + cursorOffset, textY + 3, 2, font.size))

method onTouchEv(t: TextField, e: var Event): bool =
    result = false
    var pt = e.localPosition
    case e.buttonState
    of bsDown:
        if t.editable:
            result = t.makeFirstResponder()
            if t.text.isNil:
                cursorPos = 0
                cursorOffset = 0
            else:
                systemFont().getClosestCursorPositionToPointInString(t.text, pt, cursorPos, cursorOffset)

            t.textSelection = (true, true, cursorPos, -1)

    of bsUp:
        if t.editable:
            if not t.textSelection.selected:
                discard
            else:

                t.textSelection.inSelection = false
                systemFont().getClosestCursorPositionToPointInString(t.text, pt, cursorPos, cursorOffset)

                t.textSelection.endIndex = cursorPos
                if (t.textSelection.endIndex - t.textSelection.startIndex == 0) or t.textSelection.endIndex == -1:
                    t.textSelection = (false, false, -1, -1)

                t.setNeedsDisplay()

        result = false

    of bsUnknown:
        if t.editable:
            if t.textSelection.inSelection:
                systemFont().getClosestCursorPositionToPointInString(t.text, pt, cursorPos, cursorOffset)
                t.textSelection.endIndex = cursorPos
                t.setNeedsDisplay()

            result = false

proc updateCursorOffset(t: TextField) =
    cursorOffset = systemFont().cursorOffsetForPositionInString(t.text, cursorPos)

proc clearSelection(t: TextField) =
    # Clears selected text
    if t.textSelection.startIndex < t.textSelection.endIndex:
        t.text.uniDelete(t.textSelection.startIndex, t.textSelection.endIndex - 1)
        cursorPos = t.textSelection.startIndex
        t.updateCursorOffset()
    else:
        t.text.uniDelete(t.textSelection.endIndex, t.textSelection.startIndex - 1)
        cursorPos = t.textSelection.endIndex
        t.updateCursorOffset()

    t.textSelection = (false, false, -1, -1)

method onKeyDown*(t: TextField, e: var Event): bool =
    if e.keyCode == VirtualKey.Backspace:
        result = true
        if t.textSelection.selected: t.clearSelection()
        elif cursorPos > 0:
            t.text.uniDelete(cursorPos - 1, cursorPos - 1)
            dec cursorPos
        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Delete and not t.text.isNil:
        if t.textSelection.selected: t.clearSelection()
        elif cursorPos < t.text.runeLen:
            t.text.uniDelete(cursorPos, cursorPos)
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Left:
        dec cursorPos
        if cursorPos < 0: cursorPos = 0

        if (alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift)) and t.text != "" and t.text != nil:
            if t.textSelection.selected:
                if t.textSelection.endIndex > t.textSelection.startIndex: dec(t.textSelection.startIndex)
                elif t.textSelection.endIndex < t.textSelection.startIndex: dec(t.textSelection.endIndex)
            else:
                t.textSelection = (true, false, cursorPos + 1, cursorPos)
        else:
            t.textSelection = (false, false, -1 , -1)
        t.updateCursorOffset()
        t.bumpCursorVisibility()
        t.setNeedsDisplay()
    elif e.keyCode == VirtualKey.Right:
        inc cursorPos
        let textLen = t.text.runeLen
        if cursorPos > textLen: cursorPos = textLen

        if (alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift)) and t.text != "" and t.text != nil:
            if t.textSelection.selected:
                if t.textSelection.endIndex >= t.textSelection.startIndex: inc(t.textSelection.endIndex)
                else: inc(t.textSelection.startIndex)
            else:
                t.textSelection = (true, false, cursorPos - 1, cursorPos)
        else:
            t.textSelection = (false, false, -1, -1)

        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Return:
        t.sendAction()
        t.textSelection = (false, false, -1 , -1)

method onTextInput*(t: TextField, s: string): bool =
    result = true
    if t.text.isNil: t.text = ""

    if t.textSelection.selected:
        t.clearSelection()
        return procCall onTextInput(t, s)

    t.text.insert(cursorPos, s)
    cursorPos += s.runeLen
    t.updateCursorOffset()
    t.bumpCursorVisibility()


method viewShouldResignFirstResponder*(v: TextField, newFirstResponder: View): bool =
    result = true
    cursorUpdateTimer.clear()
    cursorVisible = false
    v.textSelection = (false, false, -1, -1)
    v.sendAction()

method viewDidBecomeFirstResponder*(t: TextField) =
    t.window.startTextInput(t.convertRectoToWindow(t.bounds))
    cursorPos = if t.text.isNil: 0 else: t.text.len
    t.updateCursorOffset()
    t.bumpCursorVisibility()
