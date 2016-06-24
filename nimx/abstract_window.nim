
import view
import animation
import times
import context
import font
import composition

export view

# Window type is defined in view module

#TODO: Window size has two notions. Think about it.

const DEFAULT_RUNNER = 0

method `title=`*(w: Window, t: string) {.base.} = discard
method title*(w: Window): string {.base.} = ""

method onResize*(w: Window, newSize: Size) {.base.} =
    procCall w.View.setFrameSize(newSize)

# Bug 2488. Can not use {.global.} for JS target.
var lastTime = epochTime()
var lastFrame = 0.0
var deltaTime = 0.0
var totalAnims = 0

proc fps(): int =
    let curTime = epochTime()
    deltaTime = curTime - lastTime
    lastFrame = (lastFrame * 0.9 + deltaTime * 0.1)
    result = (1.0 / lastFrame).int
    lastTime = curTime

method drawWindow*(w: Window) {.base.} =
    w.needsDisplay = false

    w.recursiveDrawSubviews()
    let c = currentContext()
    var pt = newPoint(w.frame.width - 110, 2)
    c.fillColor = newColor(1, 0, 0, 1)
    c.drawText(systemFont(), pt, "FPS: " & $fps())

    when enableGraphicsProfiling:
        var pt2 = newPoint(w.frame.width - 110, 22)
        var pt3 = newPoint(w.frame.width - 110, 42)
        var pt4 = newPoint(w.frame.width - 110, 62)
        c.drawText(systemFont(), pt2, "Overdraw: " & $GetOverdrawValue())
        c.drawText(systemFont(), pt3, "DIPs: " & $GetDIPValue())
        c.drawText(systemFont(), pt4, "Animations: " & $totalAnims)
        ResetOverdrawValue()
        ResetDIPValue()

method enableAnimation*(w: Window, flag: bool) {.base.} = discard

method startTextInput*(w: Window, r: Rect) {.base.} = discard
method stopTextInput*(w: Window) {.base.} = discard

proc runAnimations*(w: Window) =
    # New animations can be added while in the following loop. They will
    # have to be ticked on the next frame.
    totalAnims = 0
    if not w.isNil:

        for runner in w.animationRunners:
            totalAnims += runner.animations.len
            runner.update(deltaTime)

        if totalAnims > 0:
            w.needsDisplay = true

proc animationAdded(w: Window, count: int = 1)=
    var animsCount = 0

    for runner in w.animationRunners:
        animsCount += runner.animations.len

    if animsCount >= 1 and totalAnims == 0:
        w.enableAnimation(true)

    totalAnims += count

proc animationRemoved(w: Window, count: int = 1)=
    var animsCount = 0

    totalAnims -= count

    for runner in w.animationRunners:
        animsCount += runner.animations.len

    if animsCount == 0 and totalAnims == 0:
        w.enableAnimation(false)

proc addAnimationRunner*(w: Window, ar: AnimationRunner)=
    if not w.isNil:
        if not (ar in w.animationRunners):
            w.animationRunners.add(ar)

            ar.onAnimationAdded = proc()=
                w.animationAdded()

            ar.onAnimationRemoved = proc()=
                w.animationRemoved()

            if ar.animations.len > 0:
                w.animationAdded(ar.animations.len)

proc `animations`*(w: Window): seq[Animation]=
    if not w.isNil:
        result = w.animationRunners[DEFAULT_RUNNER].animations

proc removeAnimationRunner*(w: Window, ar: AnimationRunner)=
    if not w.isNil:
        for idx, runner in w.animationRunners:
            if runner == ar:
                if idx == DEFAULT_RUNNER: break
                w.animationRunners.delete(idx)
                if runner.animations.len > 0:
                    w.animationRemoved( runner.animations.len )
                break

proc addAnimation*(w: Window, a: Animation) =
    if not w.isNil:
        w.animationRunners[DEFAULT_RUNNER].pushAnimation(a)

var newWindow*: proc(r: Rect): Window
var newFullscreenWindow*: proc(): Window

method init*(w: Window, frame: Rect) =
    procCall w.View.init(frame)
    w.window = w
    w.needsDisplay = true
    w.mouseOverListeners = @[]
    w.animationRunners = @[]

    #default animation runner for window
    var defaultRunner = newAnimationRunner()
    w.addAnimationRunner(defaultRunner)