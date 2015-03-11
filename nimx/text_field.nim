import control
import context
import font
import types
import event
import window
import times

import strutils


type TextField* = ref object of Control
    text*: string
    editable*: bool
    selectable*: bool

var cursorPos = 0
var cursorBlinkTime = 0.0
var cursorVisible = true

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
    var cursorOffset = leftMargin
    let font = systemFont()

    var textY = (t.bounds.height - font.size) / 2

    if t.text != nil:
        var textSize = font.sizeOfString(t.text)
        var pt = newPoint(leftMargin, textY)
        c.fillColor = blackColor()
        c.drawText(systemFont(), pt, t.text)
        let cPos = min(t.text.len, cursorPos)
        if cPos > 0:
            cursorOffset += font.sizeOfString(t.text[0 .. cPos - 1]).width

    if t.isEditing:
        drawCursorWithRect(newRect(cursorOffset, textY + 3, 2, font.size))

method onMouseDown*(t: TextField, e: var Event): bool =
    if t.editable:
        result = t.makeFirstResponder()
        t.window.startTextInput()
        var pt = e.localPosition
        pt.x += leftMargin
        cursorPos = if t.text.isNil:
                0
            else:
                systemFont().closestCursorPositionToPointInString(t.text, e.localPosition)
        bumpCursorVisibility()

import sdl2 except Event

method onKeyDown*(t: TextField, e: var Event): bool =
    if e.keyCode == K_BACKSPACE and cursorPos > 0:
        result = true
        t.text.delete(cursorPos - 1, cursorPos - 1)
        dec cursorPos
        echo cursorPos
        bumpCursorVisibility()
    elif e.keyCode == K_LEFT:
        dec cursorPos
        if cursorPos < 0: cursorPos = 0
        bumpCursorVisibility()
    elif e.keyCode == K_RIGHT:
        inc cursorPos
        if cursorPos > t.text.len: cursorPos = t.text.len
        bumpCursorVisibility()

method onTextInput*(t: TextField, s: string): bool =
    result = true
    if t.text.isNil: t.text = ""
    let substringStart = t.text[0 .. cursorPos]
    let substringEnd = t.text[cursorPos + 1 .. t.text.len]
    t.text = substringStart & s & substringEnd
    cursorPos += s.len

