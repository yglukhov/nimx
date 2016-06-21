
import view
import animation
import times
import context
import font

import composition

export view

# Window type is defined in view module


#TODO: Window size has two notions. Think about it.

method init*(w: Window, frame: Rect) =
    procCall w.View.init(frame)
    w.window = w
    w.animations = @[]
    w.needsDisplay = true
    w.mouseOverListeners = @[]

method `title=`*(w: Window, t: string) {.base.} = discard
method title*(w: Window): string {.base.} = ""

method onResize*(w: Window, newSize: Size) {.base.} =
    procCall w.View.setFrameSize(newSize)

# Bug 2488. Can not use {.global.} for JS target.
var lastTime = epochTime()
var lastFrame = 0.0

proc fps(): int =
    let curTime = epochTime()
    let thisFrame = curTime - lastTime
    lastFrame = (lastFrame * 0.9 + thisFrame * 0.1)
    result = (1.0 / lastFrame).int
    lastTime = curTime

method drawWindow*(w: Window) {.base.} =
    w.needsDisplay = false

    w.recursiveDrawSubviews()

    let font = systemFontOfSize(w.bounds.height/45)
    let c = currentContext()
    let offset = w.frame.width - 10
    c.fillColor = newColor(1, 0, 0, 1)

    let fps_str = "FPS: " & $fps()
    var text_size = font.sizeOfString(fps_str)
    var offsetY :float = 2
    var fps_point = newPoint(offset - text_size.width, offsetY)
    c.drawText(font, fps_point, fps_str)
    offsetY += text_size.height + 2

    when enableGraphicsProfiling:
        let over_str = "Overdraw: " & $GetOverdrawValue()
        text_size = font.sizeOfString(over_str)
        var over_point = newPoint(offset - text_size.width, offsetY)
        offsetY += text_size.height + 2

        let dips_str = "DIPs: " & $GetDIPValue()
        text_size = font.sizeOfString(dips_str)
        var dips_point = newPoint(offset - text_size.width, offsetY)
        offsetY += text_size.height + 2
        c.drawText(font, over_point, over_str)
        c.drawText(font, dips_point, dips_str)

        ResetOverdrawValue()
        ResetDIPValue()

method enableAnimation*(w: Window, flag: bool) {.base.} = discard

method startTextInput*(w: Window, r: Rect) {.base.} = discard
method stopTextInput*(w: Window) {.base.} = discard

proc runAnimations*(w: Window) =
    # New animations can be added while in the following loop. They will
    # have to be ticked on the next frame.
    let count = w.animations.len
    var finishedAnimations = 0
    if w.animations.len > 0:
        let t = epochTime()
        w.needsDisplay = true
        for i in 0 ..< count:
            w.animations[i].tick(t)
            if w.animations[i].finished: inc finishedAnimations

    # Delete animations that have finished
    if finishedAnimations > 0:
        var i = 0
        while finishedAnimations > 0 and i < w.animations.len:
            if w.animations[i].finished:
                w.animations.del(i)
                dec finishedAnimations
            else:
                inc i
        if w.animations.len == 0:
            w.enableAnimation(false)

proc addAnimation*(w: Window, a: Animation) =
    if not w.isNil:
        if w.animations.len == 0:
            w.enableAnimation(true)
        a.prepare(epochTime())
        w.animations.add(a)

var newWindow*: proc(r: Rect): Window
var newFullscreenWindow*: proc(): Window
