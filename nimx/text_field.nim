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
import pasteboard.pasteboard
import key_commands

export control

type TextField* = ref object of Control
    mText*: string
    editable*: bool
    continuous*: bool
    textColor*: Color
    mFont*: Font
    textSelection: Slice[int]

template len[T](s: Slice[T]): T = s.b - s.a

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
    t.textSelection = -1 .. -1
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

    cursorUpdateTimer = setInterval(0.5) do():
        cursorVisible = not cursorVisible
        t.setNeedsDisplay()

proc updateSelectionWithCursorPos(v: TextField, prev, cur: int) =
    if v.textSelection.len == 0:
        v.textSelection.a = prev
        v.textSelection.b = cur
    elif v.textSelection.a == prev:
        v.textSelection.a = cur
    elif v.textSelection.b == prev:
        v.textSelection.b = cur
    if v.textSelection.a > v.textSelection.b:
        swap(v.textSelection.a, v.textSelection.b)

proc selectInRange*(t: TextField, a, b: int) =
    var aa = clamp(a, 0, t.mText.len)
    var bb = clamp(b, 0, t.mText.len)
    if bb < aa: swap(aa, bb)
    if aa == bb:
        t.textSelection.a = 0
        t.textSelection.b = 0
    else:
        t.textSelection.a = aa
        t.textSelection.b = bb

proc selectAll*(t: TextField) = t.selectInRange(0, t.mText.len)

proc selectionRange(t: TextField): Slice[int] =
    result = t.textSelection
    if result.a > result.b: swap(result.a, result.b)

proc selectedText*(t: TextField): string =
    let s = t.selectionRange()
    if s.len > 0:
        if not t.mText.isNil:
            result = t.mText.runeSubStr(s.a, s.b - s.a)

method draw*(t: TextField, r: Rect) =
    let c = currentContext()
    if t.editable:
        c.fillColor = whiteColor()
        c.strokeColor = newGrayColor(0.74)
        c.strokeWidth = 1.0
        c.drawRect(t.bounds)

    let font = t.font()

    let fh = font.height
    var textY = (t.bounds.height - fh) / 2

    if t.textSelection.len > 0:
        c.fillColor = newColor(0.0, 0.0, 1.0, 0.5)
        let
            startPoint = font.cursorOffsetForPositionInString(t.text, t.textSelection.a)
            endPoint = font.cursorOffsetForPositionInString(t.text, t.textSelection.b)

        if startPoint < endPoint:
            c.drawRect(newRect(leftMargin + startPoint, textY, endPoint - startPoint, fh))
        else:
            c.drawRect(newRect(leftMargin + endPoint, textY, startPoint - endPoint, fh))

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
        drawCursorWithRect(newRect(leftMargin + cursorOffset, textY, 2, fh))

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

            t.textSelection = cursorPos .. cursorPos

    of bsUp:
        if t.editable:
            if t.textSelection.len != 0:

                let oldPos = cursorPos
                t.font.getClosestCursorPositionToPointInString(t.text, pt, cursorPos, cursorOffset)
                t.updateSelectionWithCursorPos(oldPos, cursorPos)
                if t.textSelection.len == 0:
                    t.textSelection = -1 .. -1

                t.setNeedsDisplay()

        result = false

    of bsUnknown:
        if t.editable:
            let oldPos = cursorPos
            t.font.getClosestCursorPositionToPointInString(t.text, pt, cursorPos, cursorOffset)
            t.updateSelectionWithCursorPos(oldPos, cursorPos)
            t.setNeedsDisplay()

            result = false

proc updateCursorOffset(t: TextField) =
    cursorOffset = t.font.cursorOffsetForPositionInString(t.mText, cursorPos)

proc clearSelection(t: TextField) =
    # Clears selected text
    let s = t.selectionRange()
    t.mText.uniDelete(s.a, s.b - 1)
    cursorPos = s.a
    t.updateCursorOffset()
    t.textSelection = -1 .. -1

proc insertText(t: TextField, s: string) =
    if t.mText.isNil: t.mText = ""

    if t.textSelection.len > 0:
        t.clearSelection()

    t.mText.insert(cursorPos, s)
    cursorPos += s.runeLen
    t.updateCursorOffset()
    t.bumpCursorVisibility()

    if t.continuous:
        t.sendAction()

method onKeyDown*(t: TextField, e: var Event): bool =
    if e.keyCode == VirtualKey.Backspace:
        result = true
        if t.textSelection.len > 0: t.clearSelection()
        elif cursorPos > 0:
            t.mText.uniDelete(cursorPos - 1, cursorPos - 1)
            dec cursorPos
            if t.continuous:
                t.sendAction()

        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Delete and not t.mText.isNil:
        if t.textSelection.len > 0: t.clearSelection()
        elif cursorPos < t.mText.runeLen:
            t.mText.uniDelete(cursorPos, cursorPos)
            if t.continuous:
                t.sendAction()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Left:
        let oldCursorPos = cursorPos
        dec cursorPos
        if cursorPos < 0: cursorPos = 0
        if (alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift)) and t.mText.len > 0:
            t.updateSelectionWithCursorPos(oldCursorPos, cursorPos)
        else:
            t.textSelection = -1 .. -1
        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Right:
        let oldCursorPos = cursorPos
        inc cursorPos
        let textLen = t.mText.runeLen
        if cursorPos > textLen: cursorPos = textLen

        if (alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift)) and t.mText.len > 0:
            t.updateSelectionWithCursorPos(oldCursorPos, cursorPos)
        else:
            t.textSelection = -1 .. -1

        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.Return:
        t.sendAction()
        t.textSelection = -1 .. -1
    elif e.keyCode == VirtualKey.Home:
        if alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift):
            t.updateSelectionWithCursorPos(cursorPos, 0)
        else:
            t.textSelection = -1 .. -1

        cursorPos = 0
        t.updateCursorOffset()
        t.bumpCursorVisibility()
    elif e.keyCode == VirtualKey.End:
        if alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift):
            t.updateSelectionWithCursorPos(cursorPos, t.mText.runeLen)
        else:
            t.textSelection = -1 .. -1

        cursorPos = t.mText.runeLen
        t.updateCursorOffset()
        t.bumpCursorVisibility()

    when defined(macosx) or defined(windows):
        let cmd = commandFromEvent(e)
        case cmd
        of kcPaste:
            let s = pasteboardWithName(PboardGeneral).readString()
            if not s.isNil:
                t.insertText(s)
        of kcCopy, kcCut, kcUseSelectionForFind:
            let s = t.selectedText()
            if not s.isNil:
                if cmd == kcUseSelectionForFind:
                    pasteboardWithName(PboardFind).writeString(s)
                else:
                    pasteboardWithName(PboardGeneral).writeString(s)
                if cmd == kcCut:
                    t.clearSelection()
        else: discard

method onTextInput*(t: TextField, s: string): bool =
    result = true
    t.insertText(s)

method viewShouldResignFirstResponder*(v: TextField, newFirstResponder: View): bool =
    result = true
    cursorUpdateTimer.clear()
    cursorVisible = false
    v.textSelection = -1 .. -1
    v.sendAction()

method viewDidBecomeFirstResponder*(t: TextField) =
    t.window.startTextInput(t.convertRectToWindow(t.bounds))
    cursorPos = if t.mText.isNil: 0 else: t.mText.len
    t.updateCursorOffset()
    t.bumpCursorVisibility()

method visitProperties*(v: TextField, pv: var PropertyVisitor) =
    procCall v.Control.visitProperties(pv)
    pv.visitProperty("text", v.text)
    pv.visitProperty("editable", v.editable)
    pv.visitProperty("textColor", v.textColor)

method serializeFields*(v: TextField, s: Serializer) =
    procCall v.View.serializeFields(s)
    s.serialize("text", v.text)
    s.serialize("editable", v.editable)
    s.serialize("textColor", v.textColor)

method deserializeFields*(v: TextField, s: Deserializer) =
    procCall v.View.deserializeFields(s)
    s.deserialize("text", v.mText)
    s.deserialize("editable", v.editable)
    s.deserialize("textColor", v.textColor)

registerClass(TextField)
