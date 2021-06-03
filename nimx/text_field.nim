import control
import context
import font
import types
import event
import window
import unistring
import unicode
import timer
import table_view_cell
import window_event_handling
import property_visitor
import serializers
import pasteboard/pasteboard
import key_commands
import formatted_text
import scroll_view

import nimx / meta_extensions / [ property_desc, visitors_gen, serializers_gen ]

export control

type
    TextField* = ref object of Control
        mText: FormattedText
        mEditable: bool
        continuous*: bool
        mSelectable: bool
        isSelecting*: bool
        mFont*: Font
        selectionStartLine: int
        selectionEndLine: int
        textSelection: Slice[int]
        multiline*: bool
        hasBezel*: bool

    Label* = ref object of TextField

template len[T](s: Slice[T]): T = s.b - s.a

var cursorPos = 0 # TODO: globals
var cursorVisible = true
var cursorUpdateTimer : Timer

proc selectable*(t: TextField): bool = t.mSelectable

proc `selectable=`*(t: TextField, v: bool) =
    if v:
        t.backgroundColor.a = 1.0
    else:
        t.backgroundColor.a = 0.0
    t.mSelectable = v

proc editable*(t: TextField): bool = t.mEditable

proc `editable=`*(t: TextField, v: bool)=
    if v:
        t.backgroundColor.a = 1.0
    else:
        t.backgroundColor.a = 0.0
    t.mEditable = v

var cursorOffset : Coord

const leftMargin = 3.0

proc `cursorPosition=`*(t: TextField, pos: int)

proc `text=`*(tf: TextField, text: string) =
    tf.mText.text = text
    tf.setNeedsDisplay()

    if tf.isFirstResponder and cursorPos > tf.mText.text.len():
        tf.cursorPosition = tf.mText.text.len()

proc text*(tf: TextField) : string =
    result = tf.mText.text

proc `formattedText=`*(tf: TextField, t: FormattedText) =
    tf.mText = t
    tf.setNeedsDisplay()

template formattedText*(tf: TextField): FormattedText = tf.mText

proc newTextField*(gfx: GraphicsContext, r: Rect): TextField {.deprecated.} =
    result.new()
    result.init(gfx, r)

proc newTextField*(parent: View = nil, gfx: GraphicsContext, position: Point = newPoint(0, 0), size: Size = newSize(100, 20), text: string = ""): TextField =
    result = newTextField(gfx, newRect(position.x, position.y, size.width, size.height))
    result.editable = true
    result.selectable = true
    result.mText.text = text
    if not isNil(parent):
        parent.addSubview(result)

proc newLabel*(gfx: GraphicsContext, r: Rect): TextField {.deprecated.} =
    result = newTextField(gfx, r)
    result.editable = false
    result.selectable = false
    result.backgroundColor.a = 0

proc newLabel*(parent: View = nil, gfx: GraphicsContext, position: Point = newPoint(0, 0), size: Size = newSize(100, 20), text: string = "label"): TextField =
    result = newLabel(gfx, newRect(position.x, position.y, size.width, size.height))
    result.editable = false
    result.selectable = false
    result.mText.text = text
    if not isNil(parent):
        parent.addSubview(result)

proc `textColor=`*(t: TextField, c: Color) =
    template gfx: untyped = t.gfx
    template fontCtx: untyped = gfx.fontCtx
    template gl: untyped = gfx.gl
    setTextColorInRange(fontCtx, gl, t.mText, 0, -1, c)

proc textColor*(t: TextField): Color =
    template gfx: untyped = t.gfx
    template fontCtx: untyped = gfx.fontCtx
    template gl: untyped = gfx.gl
    colorOfRuneAtPos(fontCtx, gl, t.mText, 0).color1

method init*(t: TextField, gfx: GraphicsContext, r: Rect) =
    procCall t.Control.init(gfx, r)
    t.editable = true
    t.selectable = true
    t.textSelection = -1 .. -1
    t.backgroundColor = whiteColor()
    t.hasBezel = true
    t.mText = newFormattedText()
    t.mText.verticalAlignment = vaCenter

method init*(v: Label, gfx: GraphicsContext, r: Rect) =
    procCall v.TextField.init(gfx, r)
    v.editable = false
    v.selectable = false

proc `font=`*(t: TextField, f: Font) =
    template gfx: untyped = t.gfx
    template fontCtx: untyped = gfx.fontCtx
    template gl: untyped = gfx.gl
    t.mFont = f
    setFontInRange(fontCtx, gl, t.mText, 0, -1, t.mFont)

proc font*(t: TextField): Font =
    template gfx: untyped = t.gfx
    template fontCtx: untyped = gfx.fontCtx
    if t.mFont.isNil:
        result = systemFont(fontCtx)
    else:
        result = t.mFont

proc isEditing*(t: TextField): bool =
    t.editable and t.isFirstResponder

proc drawCursorWithRect(c: GraphicsContext, r: Rect) =
    if cursorVisible:
        c.fillColor = newGrayColor(0.28)
        c.strokeWidth = 0
        c.drawRect(r)

proc cursorRect(t: TextField): Rect =
    template gfx: untyped = t.gfx
    template fontCtx: untyped = gfx.fontCtx
    template gl: untyped = gfx.gl
    let ln = lineOfRuneAtPos(fontCtx, gl, t.mText, cursorPos)
    let y = lineTop(fontCtx, gl, t.mText, ln) + topOffset(fontCtx, gl, t.mText)
    let fh = lineHeight(fontCtx, gl, t.mText, ln)
    let lineX = lineLeft(fontCtx, gl, t.mText, ln)
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
    selectInRange(t, 0, t.mText.text.len)
    t.setNeedsDisplay()

proc selectionRange(t: TextField): Slice[int] =
    result = t.textSelection
    if result.a > result.b: swap(result.a, result.b)

proc selectedText*(t: TextField): string =
    let s = selectionRange(t)
    if s.len > 0:
        if not t.mText.isNil:
            result = runeSubStr(t.mText.text, s.a, s.b - s.a)

proc drawSelection(t: TextField) {.inline.} =
    template gfx: untyped = t.gfx
    template fontCtx: untyped = t.gfx.fontCtx
    template gl: untyped = t.gfx.gl
    gfx.fillColor = newColor(0.0, 0.0, 1.0, 0.5)
    let startLine = lineOfRuneAtPos(fontCtx, gl, t.mText, t.textSelection.a)
    let endLine = lineOfRuneAtPos(fontCtx, gl, t.mText, t.textSelection.b)
    let startOff = xOfRuneAtPos(fontCtx, gl, t.mText, t.textSelection.a)
    let endOff = xOfRuneAtPos(fontCtx, gl, t.mText, t.textSelection.b)
    let top = topOffset(fontCtx, gl, t.mText)
    var r: Rect
    r.origin.y = lineTop(fontCtx, gl, t.mText, startLine) + top
    r.size.height = lineHeight(fontCtx, gl, t.mText, startLine)
    let lineX = lineLeft(fontCtx, gl, t.mText, startLine)
    r.origin.x = leftMargin + startOff + lineX
    if endLine == startLine:
        r.size.width = endOff - startOff
    else:
        r.size.width = lineWidth(fontCtx, gl, t.mText, startLine) - startOff
    gfx.drawRect(r)
    for i in startLine + 1 ..< endLine:
        r.origin.y = lineTop(fontCtx, gl, t.mText, i) + top
        r.size.height = lineHeight(fontCtx, gl, t.mText, i)
        r.origin.x = leftMargin + lineLeft(fontCtx, gl, t.mText, i)
        r.size.width = lineWidth(fontCtx, gl, t.mText, i)
        if r.size.width < 5: r.size.width = 5
        gfx.drawRect(r)
    if startLine != endLine:
        r.origin.y = lineTop(fontCtx, gl, t.mText, endLine) + top
        r.size.height = lineHeight(fontCtx, gl, t.mText, endLine)
        r.origin.x = leftMargin + lineLeft(fontCtx, gl, t.mText, endLine)
        r.size.width = endOff
        gfx.drawRect(r)

#todo: replace by generic visibleRect which should be implemented in future
proc visibleRect(t: TextField): Rect =
    let wndRect = t.convertRectToWindow(t.bounds)
    let wndBounds = t.window.bounds

    result.origin.y = if wndRect.y < 0.0: abs(wndRect.y) else: 0.0
    result.size.width = t.bounds.width
    result.size.height = min(t.bounds.height, wndBounds.height) + result.y - max(wndRect.y, 0.0)

method draw*(t: TextField, r: Rect) =
    procCall t.View.draw(r)

    template gfx: untyped = t.gfx

    if t.editable and t.hasBezel:
        gfx.fillColor = t.backgroundColor
        gfx.strokeColor = newGrayColor(0.74)
        gfx.strokeWidth = 1.0
        gfx.drawRect(t.bounds)

    t.mText.boundingSize = t.bounds.size

    if t.textSelection.len > 0:
        t.drawSelection()

    var pt = newPoint(leftMargin, 0)
    let cell = t.enclosingTableViewCell()
    if not cell.isNil and cell.selected:
        t.mText.overrideColor = whiteColor()
    else:
        t.mText.overrideColor.a = 0

    if t.bounds.height > t.window.bounds.height:
        gfx.drawText(pt, t.mText, t.visibleRect())
    else:
        gfx.drawText(pt, t.mText)

    if t.isEditing:
        if t.hasBezel:
            t.drawFocusRing()
        drawCursorWithRect(gfx, t.cursorRect())

method acceptsFirstResponder*(t: TextField): bool = t.editable

method onTouchEv*(t: TextField, e: var Event): bool =
    result = false
    template fontCtx: untyped = t.gfx.fontCtx
    template gl: untyped = t.gfx.gl
    var pt = e.localPosition
    case e.buttonState
    of bsDown:
        if t.selectable:
            if not t.isFirstResponder():
                result = t.makeFirstResponder()
                t.isSelecting = false
            else:
                result = true
                t.isSelecting = true
                if t.mText.isNil:
                    cursorPos = 0
                    cursorOffset = 0
                else:
                    getClosestCursorPositionToPoint(fontCtx, gl, t.mText, pt, cursorPos, cursorOffset)
                    t.textSelection = cursorPos .. cursorPos
                t.bumpCursorVisibility()

    of bsUp:
        if t.selectable and t.isSelecting:
            t.isSelecting = false
            t.window.startTextInput(t.convertRectToWindow(t.bounds))
            if t.textSelection.len != 0:
                let oldPos = cursorPos
                getClosestCursorPositionToPoint(fontCtx, gl, t.mText, pt, cursorPos, cursorOffset)
                t.updateSelectionWithCursorPos(oldPos, cursorPos)
                if t.textSelection.len == 0:
                    t.textSelection = -1 .. -1

                t.setNeedsDisplay()

            result = false

    of bsUnknown:
        if t.selectable:
            let oldPos = cursorPos
            getClosestCursorPositionToPoint(fontCtx, gl, t.mText, pt, cursorPos, cursorOffset)
            t.updateSelectionWithCursorPos(oldPos, cursorPos)
            t.setNeedsDisplay()

            result = false

proc updateCursorOffset(t: TextField) =
    template fontCtx: untyped = t.gfx.fontCtx
    template gl: untyped = t.gfx.gl
    cursorOffset = xOfRuneAtPos(fontCtx, gl, t.mText, cursorPos)

proc `cursorPosition=`*(t: TextField, pos: int) =
    cursorPos = pos
    t.updateCursorOffset()
    t.bumpCursorVisibility()

proc clearSelection(t: TextField) =
    template gfx: untyped = t.gfx
    template fontCtx: untyped = t.gfx.fontCtx
    template gl: untyped = t.gfx.gl
    # Clears selected text
    let s = t.selectionRange()
    uniDelete(fontCtx, gl, t.mText, s.a, s.b - 1)
    cursorPos = s.a
    t.updateCursorOffset()
    t.textSelection = -1 .. -1

proc insertText(t: TextField, s: string) =
    template fontCtx: untyped = t.gfx.fontCtx
    template gl: untyped = t.gfx.gl

    let th = totalHeight(fontCtx, gl, t.mText)
    if t.textSelection.len > 0:
        t.clearSelection()

    uniInsert(fontCtx, gl, t.mText, cursorPos, s)
    cursorPos += s.runeLen
    t.updateCursorOffset()
    t.bumpCursorVisibility()

    let newTh = totalHeight(fontCtx, gl, t.mText)
    if th != newTh:
        var s = t.bounds.size
        s.height = newTh
        t.superview.subviewDidChangeDesiredSize(t, s)

    if t.continuous:
        t.sendAction()

method onKeyDown*(t: TextField, e: var Event): bool =
    template fontCtx: untyped = t.gfx.fontCtx
    template gl: untyped = t.gfx.gl
    if e.keyCode == VirtualKey.Tab:
        return false

    if t.editable:
        if e.keyCode == VirtualKey.Backspace:
            if t.textSelection.len > 0: t.clearSelection()
            elif cursorPos > 0:
                uniDelete(fontCtx, gl, t.mText, cursorPos - 1, cursorPos - 1)
                dec cursorPos
                if t.continuous:
                    t.sendAction()

            t.updateCursorOffset()
            t.bumpCursorVisibility()
            result = true
        elif e.keyCode == VirtualKey.Delete and not t.mText.isNil:
            if t.textSelection.len > 0: t.clearSelection()
            elif cursorPos < t.mText.runeLen:
                uniDelete(fontCtx, gl, t.mText, cursorPos, cursorPos)
                if t.continuous:
                    t.sendAction()
            t.bumpCursorVisibility()
            result = true
        elif e.keyCode == VirtualKey.Left:
            let oldCursorPos = cursorPos
            dec cursorPos
            if cursorPos < 0: cursorPos = 0
            if e.modifiers.anyShift() and t.mText.len > 0:
                t.updateSelectionWithCursorPos(oldCursorPos, cursorPos)
            else:
                t.textSelection = -1 .. -1
            t.updateCursorOffset()
            t.bumpCursorVisibility()
            result = true
        elif e.keyCode == VirtualKey.Right:
            let oldCursorPos = cursorPos
            inc cursorPos
            let textLen = t.mText.runeLen
            if cursorPos > textLen: cursorPos = textLen

            if e.modifiers.anyShift() and t.mText.len > 0:
                t.updateSelectionWithCursorPos(oldCursorPos, cursorPos)
            else:
                t.textSelection = -1 .. -1

            t.updateCursorOffset()
            t.bumpCursorVisibility()
            result = true
        elif e.keyCode == VirtualKey.Return or e.keyCode == VirtualKey.KeypadEnter:
            if t.multiline:
                t.insertText("\l")
            else:
                t.sendAction()
                t.textSelection = -1 .. -1
            result = true
        elif e.keyCode == VirtualKey.Home:
            if e.modifiers.anyShift():
                t.updateSelectionWithCursorPos(cursorPos, 0)
            else:
                t.textSelection = -1 .. -1

            cursorPos = 0
            t.updateCursorOffset()
            t.bumpCursorVisibility()
            result = true
        elif e.keyCode == VirtualKey.End:
            if e.modifiers.anyShift():
                t.updateSelectionWithCursorPos(cursorPos, t.mText.runeLen)
            else:
                t.textSelection = -1 .. -1

            cursorPos = t.mText.runeLen
            t.updateCursorOffset()
            t.bumpCursorVisibility()
            result = true
        elif t.multiline:
            if e.keyCode == VirtualKey.Down:
                let oldCursorPos = cursorPos
                let ln = lineOfRuneAtPos(fontCtx, gl, t.mText, cursorPos)
                var offset: Coord
                getClosestCursorPositionToPointInLine(fontCtx, gl, t.mText, ln + 1, newPoint(cursorOffset, 0), cursorPos, offset)
                cursorOffset = offset
                if e.modifiers.anyShift():
                    t.updateSelectionWithCursorPos(oldCursorPos, cursorPos)
                else:
                    t.textSelection = -1 .. -1
                t.bumpCursorVisibility()
                result = true
            elif e.keyCode == VirtualKey.Up:
                let oldCursorPos = cursorPos
                let ln = lineOfRuneAtPos(fontCtx, gl, t.mText, cursorPos)
                if ln > 0:
                    var offset: Coord
                    getClosestCursorPositionToPointInLine(fontCtx, gl, t.mText, ln - 1, newPoint(cursorOffset, 0), cursorPos, offset)
                    cursorOffset = offset
                    if e.modifiers.anyShift():
                        t.updateSelectionWithCursorPos(oldCursorPos, cursorPos)
                    else:
                        t.textSelection = -1 .. -1
                    t.bumpCursorVisibility()
                result = true
    if t.selectable or t.editable:
        let cmd = commandFromEvent(e)
        if cmd == kcSelectAll: t.selectAll()
        t.focusOnCursor()

        when defined(macosx) or defined(windows) or defined(linux):
            if cmd == kcPaste:
                if t.editable:
                    let s = pasteboardWithName(PboardGeneral).readString()
                    if s.len != 0:
                        t.insertText(s)
                    result = true
        when defined(macosx) or defined(windows) or defined(linux) or defined(emscripten) or defined(js):
            if cmd in { kcCopy, kcCut, kcUseSelectionForFind }:
                let s = t.selectedText()
                if s.len != 0:
                    if cmd == kcUseSelectionForFind:
                        pasteboardWithName(PboardFind).writeString(s)
                    else:
                        pasteboardWithName(PboardGeneral).writeString(s)
                    if cmd == kcCut and t.editable:
                        t.clearSelection()
                result = true

        result = result or (t.editable and e.modifiers.isEmpty())

method onTextInput*(t: TextField, s: string): bool =
    if not t.editable: return false
    result = true
    t.insertText(s)

method viewShouldResignFirstResponder*(v: TextField, newFirstResponder: View): bool =
    result = true
    cursorUpdateTimer.clear()
    cursorVisible = false
    v.textSelection = -1 .. -1

    if not v.window.isNil:
        v.window.stopTextInput()

    v.sendAction()

method viewDidBecomeFirstResponder*(t: TextField) =
    t.window.startTextInput(t.convertRectToWindow(t.bounds))
    cursorPos = if t.mText.isNil: 0 else: t.mText.runeLen
    t.updateCursorOffset()
    t.bumpCursorVisibility()

    t.selectAll()

TextField.properties:
    editable
    continuous
    mSelectable
    isSelecting
    # mFont
    multiline
    hasBezel
    text

registerClass(TextField)
genVisitorCodeForView(TextField)
genSerializeCodeForView(TextField)
