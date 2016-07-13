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
import property_visitor
import serializers

export control

type TextField* = ref object of Control
    mText*: string
    editable*: bool
    onInput*: proc(t: TextField)
    textColor*: Color
    mFont*: Font
    textSelection: tuple[selected: bool, inselection: bool, startIndex: int, endIndex: int]

var cursorPos = 0
var cursorVisible = true
var cursorUpdateTimer : Timer

var cursorOffset : Coord

const leftMargin = 3.0

proc `text=`*(tf: TextField, text: string) =
    tf.mText = text
    tf.setNeedsDisplay()

proc text*(tf: TextField) : string =
    result = tf.mText

proc newTextField*(r: Rect): TextField =
    result.new()
    result.init(r)

proc newTextField*(parent: View = nil, position: Point = newPoint(0, 0), size: Size = newSize(100, 20), text: string = ""): TextField =
    result = newTextField(newRect(position.x, position.y, size.width, size.height))
    result.editable = true
    result.mText = text
    if not isNil(parent):
        parent.addSubview(result)

proc newLabel*(r: Rect): TextField =
    result = newTextField(r)
    result.editable = false

proc newLabel*(parent: View = nil, position: Point = newPoint(0, 0), size: Size = newSize(100, 20), text: string = "label"): TextField =
    result = newLabel(newRect(position.x, position.y, size.width, size.height))
    result.editable = false
    result.mText = text
    if not isNil(parent):
        parent.addSubview(result)

method init*(t: TextField, r: Rect) =
    procCall t.Control.init(r)
    t.editable = true
    t.textSelection = (false, false, -1, -1)
    t.textColor = newGrayColor(0.0)

template `font=`*(t: TextField, f: Font) = t.mFont = f
proc font*(t: TextField): Font =
    if t.mFont.isNil:
        result = systemFont()
    else:
        result = t.mFont

proc isEditing*(t: TextField): bool =
    t.editable and t.isFirstResponder

proc drawCursorWithRect(r: Rect) =
    if cursorVisible:
        let c = currentContext()
        c.fillColor = newGrayColor(0.28)
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

proc selectInRange*(t: TextField, a, b: int) =
    var aa = clamp(a, 0, t.mText.len)
    var bb = clamp(b, 0, t.mText.len)
    if bb < aa: swap(aa, bb)
    if aa - bb == 0:
        t.textSelection.selected = false
        t.textSelection.startIndex = 0
        t.textSelection.endIndex = 0
    else:
        t.textSelection.selected = true
        t.textSelection.startIndex = aa
        t.textSelection.endIndex = bb

proc selectAll*(t: TextField) = t.selectInRange(0, t.mText.len)

method draw*(t: TextField, r: Rect) =
    let c = currentContext()
    if t.editable:
        c.fillColor = whiteColor()
        c.strokeColor = newGrayColor(0.74)
        c.strokeWidth = 1.0
        c.drawRect(t.bounds)

    let font = t.font()

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

    if t.mText != nil:
        var pt = newPoint(leftMargin, textY)
        let cell = t.enclosingTableViewCell()
        if not cell.isNil and cell.selected:
            c.fillColor = whiteColor()
        else:
            c.fillColor = t.textColor
        c.drawText(font, pt, t.mText)

    if t.isEditing:
        t.drawFocusRing()
        drawCursorWithRect(newRect(leftMargin + cursorOffset, textY, 2, font.size))

method onTouchEv*(t: TextField, e: var Event): bool =
    result = false
    var pt = e.localPosition
    case e.buttonState
    of bsDown:
        if t.editable:
            result = t.makeFirstResponder()
            if t.mText.isNil:
                cursorPos = 0
                cursorOffset = 0
            else:
                t.font.getClosestCursorPositionToPointInString(t.text, pt, cursorPos, cursorOffset)

            t.textSelection = (true, true, cursorPos, -1)

    of bsUp:
        if t.editable:
            if not t.textSelection.selected:
                discard
            else:

                t.textSelection.inSelection = false
                t.font.getClosestCursorPositionToPointInString(t.text, pt, cursorPos, cursorOffset)

                t.textSelection.endIndex = cursorPos
                if (t.textSelection.endIndex - t.textSelection.startIndex == 0) or t.textSelection.endIndex == -1:
                    t.textSelection = (false, false, -1, -1)

                t.setNeedsDisplay()

        result = false

    of bsUnknown:
        if t.editable:
            if t.textSelection.inSelection:
                t.font.getClosestCursorPositionToPointInString(t.text, pt, cursorPos, cursorOffset)
                t.textSelection.endIndex = cursorPos
                t.setNeedsDisplay()

            result = false

proc updateCursorOffset(t: TextField) =
    cursorOffset = t.font.cursorOffsetForPositionInString(t.mText, cursorPos)

proc clearSelection(t: TextField) =
    # Clears selected text
    if t.textSelection.startIndex < t.textSelection.endIndex:
        t.mText.uniDelete(t.textSelection.startIndex, t.textSelection.endIndex - 1)
        cursorPos = t.textSelection.startIndex
        t.updateCursorOffset()
    else:
        t.mText.uniDelete(t.textSelection.endIndex, t.textSelection.startIndex - 1)
        cursorPos = t.textSelection.endIndex
        t.updateCursorOffset()

    t.textSelection = (false, false, -1, -1)

method onKeyDown*(t: TextField, e: var Event): bool =
    if e.keyCode == VirtualKey.Backspace:
        result = true
        if t.textSelection.selected: t.clearSelection()
        elif cursorPos > 0:
            t.mText.uniDelete(cursorPos - 1, cursorPos - 1)
            dec cursorPos
            if not t.onInput.isNil:
                t.onInput(t)
        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Delete and not t.mText.isNil:
        if t.textSelection.selected: t.clearSelection()
        elif cursorPos < t.mText.runeLen:
            t.mText.uniDelete(cursorPos, cursorPos)
            if not t.onInput.isNil:
                t.onInput(t)
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Left:
        dec cursorPos
        if cursorPos < 0: cursorPos = 0

        if (alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift)) and t.mText != "" and t.mText != nil:
            if t.textSelection.selected: t.textSelection.endIndex = cursorPos
            else: t.textSelection = (true, false, cursorPos + 1, cursorPos)
        else:
            t.textSelection = (false, false, -1 , -1)
        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Right:
        inc cursorPos
        let textLen = t.mText.runeLen
        if cursorPos > textLen: cursorPos = textLen

        if (alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift)) and t.mText != "" and t.mText != nil:
            if t.textSelection.selected: t.textSelection.endIndex = cursorPos
            else: t.textSelection = (true, false, cursorPos - 1, cursorPos)
        else:
            t.textSelection = (false, false, -1, -1)

        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Return:
        t.sendAction()
        t.textSelection = (false, false, -1 , -1)
    elif e.keyCode == VirtualKey.Home:
        if alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift):
            if t.textSelection.selected:
                t.textSelection.endIndex = 0
            else:
                t.textSelection = (true, false, cursorPos, 0)
        else:
            t.textSelection = (false, false, -1, -1)

        cursorPos = 0
        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.End:
        if alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift):
            if t.textSelection.selected:
                t.textSelection.endIndex = t.mText.runeLen
            else:
                t.textSelection = (true, false, cursorPos, t.mText.runeLen)
        else:
            t.textSelection = (false, false, -1, -1)

        cursorPos = t.mText.runeLen
        t.updateCursorOffset()
        t.bumpCursorVisibility()

method onTextInput*(t: TextField, s: string): bool =
    result = true
    if t.mText.isNil: t.mText = ""

    if t.textSelection.selected:
        t.clearSelection()
        return procCall onTextInput(t, s)

    t.mText.insert(cursorPos, s)
    cursorPos += s.runeLen
    t.updateCursorOffset()
    t.bumpCursorVisibility()

    if not t.onInput.isNil:
        t.onInput(t)

method viewShouldResignFirstResponder*(v: TextField, newFirstResponder: View): bool =
    result = true
    cursorUpdateTimer.clear()
    cursorVisible = false
    v.textSelection = (false, false, -1, -1)
    v.sendAction()

method viewDidBecomeFirstResponder*(t: TextField) =
    t.window.startTextInput(t.convertRectToWindow(t.bounds))
    cursorPos = if t.mText.isNil: 0 else: t.mText.len
    t.updateCursorOffset()
    t.bumpCursorVisibility()

method visitProperties*(v: TextField, pv: var PropertyVisitor) =
    procCall v.Control.visitProperties(pv)
    pv.visitProperty("text", v.text)

method serializeFields*(v: TextField, s: Serializer) =
    procCall v.View.serializeFields(s)
    s.serialize("text", v.text)

method deserializeFields*(v: TextField, s: Deserializer) =
    procCall v.View.deserializeFields(s)
    s.deserialize("text", v.mText)

registerClass(TextField)
