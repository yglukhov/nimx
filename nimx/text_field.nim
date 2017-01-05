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
import formatted_text
import scroll_view

export control

type TextField* = ref object of Control
    mText: FormattedText
    #mText*: string
    editable*: bool
    continuous*: bool
    textColor*: Color
    mFont*: Font
    selectionStartLine: int
    selectionEndLine: int
    textSelection: Slice[int]
    multiline*: bool
    hasBezel*: bool

template len[T](s: Slice[T]): T = s.b - s.a

var cursorPos = 0
var cursorVisible = true
var cursorUpdateTimer : Timer

var cursorOffset : Coord

const leftMargin = 3.0

proc `cursorPosition=`*(t: TextField, pos: int)

proc `text=`*(tf: TextField, text: string) =
    tf.mText.text = text
    tf.setNeedsDisplay()

    if cursorPos > tf.mText.text.len():
        tf.cursorPosition = tf.mText.text.len()

proc text*(tf: TextField) : string =
    result = tf.mText.text

proc `formattedText=`*(tf: TextField, t: FormattedText) =
    tf.mText = t
    tf.setNeedsDisplay()

template formattedText*(tf: TextField): FormattedText = tf.mText

proc newTextField*(r: Rect): TextField =
    result.new()
    result.init(r)

proc newTextField*(parent: View = nil, position: Point = newPoint(0, 0), size: Size = newSize(100, 20), text: string = ""): TextField =
    result = newTextField(newRect(position.x, position.y, size.width, size.height))
    result.editable = true
    result.mText.text = text
    if not isNil(parent):
        parent.addSubview(result)

proc newLabel*(r: Rect): TextField =
    result = newTextField(r)
    result.editable = false

proc newLabel*(parent: View = nil, position: Point = newPoint(0, 0), size: Size = newSize(100, 20), text: string = "label"): TextField =
    result = newLabel(newRect(position.x, position.y, size.width, size.height))
    result.editable = false
    result.mText.text = text
    if not isNil(parent):
        parent.addSubview(result)

method init*(t: TextField, r: Rect) =
    procCall t.Control.init(r)
    t.editable = true
    t.textSelection = -1 .. -1
    t.textColor = newGrayColor(0.0)
    t.hasBezel = true
    t.mText = newFormattedText()
    t.mText.verticalAlignment = vaCenter

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

proc cursorRect(t: TextField): Rect =
    let ln = t.mText.lineOfRuneAtPos(cursorPos)
    let y = t.mText.lineTop(ln) + t.mText.topOffset()
    let fh = t.mText.lineHeight(ln)
    let lineX = t.mText.lineLeft(ln)
    newRect(leftMargin + cursorOffset + lineX, y, 2, fh)

proc bumpCursorVisibility(t: TextField) =
    cursorVisible = true
    cursorUpdateTimer.clear()
    t.setNeedsDisplay()

    cursorUpdateTimer = setInterval(0.5) do():
        cursorVisible = not cursorVisible
        t.setNeedsDisplay()

proc focusOnCursor(t: TextField) =
    let sv = t.enclosingViewOfType(ScrollView)
    if not sv.isNil:
        var view: View = t
        var point  = t.cursorRect().origin
        while not (view.superview of ScrollView):
            point = view.convertPointToParent(point)
            view = view.superview

        var rect = t.cursorRect()
        rect.origin = point
        sv.scrollToRect(rect)

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
    let ln = t.mText.text.runeLen
    var aa = clamp(a, 0, ln)
    var bb = clamp(b, 0, ln)
    if bb < aa: swap(aa, bb)
    if aa == bb:
        t.textSelection.a = 0
        t.textSelection.b = 0
    else:
        t.textSelection.a = aa
        t.textSelection.b = bb

proc selectAll*(t: TextField) =
    t.selectInRange(0, t.mText.text.len)
    t.setNeedsDisplay()

proc selectionRange(t: TextField): Slice[int] =
    result = t.textSelection
    if result.a > result.b: swap(result.a, result.b)

proc selectedText*(t: TextField): string =
    let s = t.selectionRange()
    if s.len > 0:
        if not t.mText.isNil:
            result = t.mText.text.runeSubStr(s.a, s.b - s.a)

proc drawSelection(t: TextField) {.inline.} =
    let c = currentContext()
    c.fillColor = newColor(0.0, 0.0, 1.0, 0.5)
    let startLine = t.mText.lineOfRuneAtPos(t.textSelection.a)
    let endLine = t.mText.lineOfRuneAtPos(t.textSelection.b)
    let startOff = t.mText.xOfRuneAtPos(t.textSelection.a)
    let endOff = t.mText.xOfRuneAtPos(t.textSelection.b)
    let top = t.mText.topOffset()
    var r: Rect
    r.origin.y = t.mText.lineTop(startLine) + top
    r.size.height = t.mText.lineHeight(startLine)
    let lineX = t.mText.lineLeft(startLine)
    r.origin.x = leftMargin + startOff + lineX
    if endLine == startLine:
        r.size.width = endOff - startOff
    else:
        r.size.width = t.mText.lineWidth(startLine) - startOff
    c.drawRect(r)
    for i in startLine + 1 ..< endLine:
        r.origin.y = t.mText.lineTop(i) + top
        r.size.height = t.mText.lineHeight(i)
        r.origin.x = leftMargin + t.mText.lineLeft(i)
        r.size.width = t.mText.lineWidth(i)
        if r.size.width < 5: r.size.width = 5
        c.drawRect(r)
    if startLine != endLine:
        r.origin.y = t.mText.lineTop(endLine) + top
        r.size.height = t.mText.lineHeight(endLine)
        r.origin.x = leftMargin + t.mText.lineLeft(endLine)
        r.size.width = endOff
        c.drawRect(r)

method draw*(t: TextField, r: Rect) =
    let c = currentContext()
    if t.editable and t.hasBezel:
        c.fillColor = whiteColor()
        c.strokeColor = newGrayColor(0.74)
        c.strokeWidth = 1.0
        c.drawRect(t.bounds)

    t.mText.boundingSize = t.bounds.size

    if t.textSelection.len > 0:
        t.drawSelection()

    var pt = newPoint(leftMargin, 0)
    let cell = t.enclosingTableViewCell()
    if not cell.isNil and cell.selected:
        t.mText.overrideColor = whiteColor()
    else:
        t.mText.overrideColor.a = 0
    c.drawText(pt, t.mText)

    if t.isEditing:
        if t.hasBezel:
            t.drawFocusRing()
        drawCursorWithRect(t.cursorRect())

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
                t.mText.getClosestCursorPositionToPoint(pt, cursorPos, cursorOffset)

                t.textSelection = cursorPos .. cursorPos

    of bsUp:
        if t.editable:
            if t.textSelection.len != 0:

                let oldPos = cursorPos
                t.mText.getClosestCursorPositionToPoint(pt, cursorPos, cursorOffset)
                t.updateSelectionWithCursorPos(oldPos, cursorPos)
                if t.textSelection.len == 0:
                    t.textSelection = -1 .. -1

                t.setNeedsDisplay()

        result = false

    of bsUnknown:
        if t.editable:
            let oldPos = cursorPos
            t.mText.getClosestCursorPositionToPoint(pt, cursorPos, cursorOffset)
            t.updateSelectionWithCursorPos(oldPos, cursorPos)
            t.setNeedsDisplay()

            result = false

proc updateCursorOffset(t: TextField) =
    cursorOffset = t.mText.xOfRuneAtPos(cursorPos)

proc `cursorPosition=`*(t: TextField, pos: int) =
    cursorPos = pos
    t.updateCursorOffset()
    t.bumpCursorVisibility()

proc clearSelection(t: TextField) =
    # Clears selected text
    let s = t.selectionRange()
    t.mText.uniDelete(s.a, s.b - 1)
    cursorPos = s.a
    t.updateCursorOffset()
    t.textSelection = -1 .. -1

proc insertText(t: TextField, s: string) =
    #if t.mText.isNil: t.mText.text = ""

    let th = t.mText.totalHeight
    if t.textSelection.len > 0:
        t.clearSelection()

    t.mText.uniInsert(cursorPos, s)
    cursorPos += s.runeLen
    t.updateCursorOffset()
    t.bumpCursorVisibility()

    let newTh = t.mText.totalHeight
    if th != newTh:
        var s = t.bounds.size
        s.height = newTh
        t.superview.subviewDidChangeDesiredSize(t, s)

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
        if t.multiline:
            t.insertText("\l")
        else:
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
    elif t.multiline:
        if e.keyCode == VirtualKey.Down:
            let oldCursorPos = cursorPos
            let ln = t.mText.lineOfRuneAtPos(cursorPos)
            var offset: Coord
            t.mText.getClosestCursorPositionToPointInLine(ln + 1, newPoint(cursorOffset, 0), cursorPos, offset)
            cursorOffset = offset
            if alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift):
                t.updateSelectionWithCursorPos(oldCursorPos, cursorPos)
            else:
                t.textSelection = -1 .. -1
            t.bumpCursorVisibility()
        elif e.keyCode == VirtualKey.Up:
            let oldCursorPos = cursorPos
            let ln = t.mText.lineOfRuneAtPos(cursorPos)
            if ln > 0:
                var offset: Coord
                t.mText.getClosestCursorPositionToPointInLine(ln - 1, newPoint(cursorOffset, 0), cursorPos, offset)
                cursorOffset = offset
                if alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift):
                    t.updateSelectionWithCursorPos(oldCursorPos, cursorPos)
                else:
                    t.textSelection = -1 .. -1
                t.bumpCursorVisibility()

    let cmd = commandFromEvent(e)
    if cmd == kcSelectAll: t.selectAll()
    t.focusOnCursor()

    when defined(macosx) or defined(windows):
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
    cursorPos = if t.mText.isNil: 0 else: t.mText.runeLen
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
