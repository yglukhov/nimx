
import view
import animation
import times
import context
import font
import composition
import resource
import image
import notification_center
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
var totalAnims = 0

proc fps(): int =
    let curTime = epochTime()
    let deltaTime = curTime - lastTime
    lastFrame = (lastFrame * 0.9 + deltaTime * 0.1)
    result = (1.0 / lastFrame).int
    lastTime = curTime

proc getTextureMemory(): int =
    var memory = 0.int
    var selfImages = findCachedResources[SelfContainedImage]()
    for img in selfImages:
        memory += int(img.size.width * img.size.height)

    var spriteImages = findCachedResources[SpriteImage]()
    for img in spriteImages:
        memory += int(img.size.width * img.size.height)

    var images = findCachedResources[Image]()
    for img in images:
        memory += int(img.size.width * img.size.height)

    var fixedImages = findCachedResources[FixedTexCoordSpriteImage]()
    for img in fixedImages:
        memory += int(img.size.width * img.size.height)

    memory = int(4 * memory / 1024 / 1024)
    return memory

method drawWindow*(w: Window) {.base.} =
    w.needsDisplay = false

    w.recursiveDrawSubviews()
    let c = currentContext()
    c.fillColor = newColor(1, 0, 0, 1)

    when enableGraphicsProfiling:
        var font = systemFont()
        let old_size = font.size
        font.size = 14
        var pt = newPoint(w.frame.width - 100, 5)
        var pt2 = newPoint(w.frame.width - 100, 20)
        var pt3 = newPoint(w.frame.width - 100, 35)
        var pt4 = newPoint(w.frame.width - 100, 50)
        var pt5 = newPoint(w.frame.width - 100, 65)
        c.drawText(font, pt, "FPS: " & $fps())
        c.drawText(font, pt2, "Overdraw: " & $GetOverdrawValue())
        c.drawText(font, pt3, "DIPs: " & $GetDIPValue())
        c.drawText(font, pt4, "Animations: " & $totalAnims)
        c.drawText(font, pt5, "TexMem: " & $getTextureMemory())
        font.size = old_size
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

        var index = 0
        let runnersLen = w.animationRunners.len

        while index < runnersLen:
            let runner = w.animationRunners[index]
            totalAnims += runner.animations.len
            runner.update()
            inc index

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

template animations*(w: Window): seq[Animation] = w.animationRunners[DEFAULT_RUNNER].animations

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

proc onFocusChange*(w: Window, inFocus: bool)=

    if inFocus:
        sharedNotificationCenter().postNotification("onFocusEnter")
    else:
        sharedNotificationCenter().postNotification("onFocusLeave")

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
