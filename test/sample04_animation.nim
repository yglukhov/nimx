import math # for PI
import nimx.view
import nimx.image
import nimx.context
import nimx.animation
import nimx.window
import sample_registry

type AnimationSampleView = ref object of View
    rotation: Coord
    animation: Animation

method init*(v: AnimationSampleView, r: Rect) =
    procCall v.View.init(r)
    v.animation = newAnimation()
    v.animation.timingFunction = bezierTimingFunction(0.53,-0.53,0.38,1.52)
    v.animation.onAnimate = proc(p: float) =
        v.rotation = p * PI * 2
    v.animation.loopDuration = 2.0

method draw(v: AnimationSampleView, r: Rect) =
    let c = currentContext()
    c.fillColor = newGrayColor(0.5)
    var tmpTransform = c.transform
    tmpTransform.translate(newVector3(v.bounds.width/2, v.bounds.height/3, 0))
    tmpTransform.rotateZ(v.rotation)
    tmpTransform.translate(newVector3(-50, -50, 0))
    c.withTransform tmpTransform:
        c.fillColor = newColor(0, 1, 1)
        c.strokeColor = newColor(0, 0, 0, 1)
        c.strokeWidth = 9.0
        c.drawEllipseInRect(newRect(0, 0, 100, 200))

    tmpTransform = c.transform

    tmpTransform.translate(newVector3(v.bounds.width/2, v.bounds.height/3 * 2, 0))
    tmpTransform.rotateZ(-v.rotation)
    tmpTransform.translate(newVector3(-50, -50, 0))

    c.fillColor = newColor(0.5, 0.5, 0)
    c.strokeWidth = 0
    c.withTransform tmpTransform:
        c.drawRoundedRect(newRect(0, 0, 100, 200), 20)

method viewWillMoveToWindow*(v: AnimationSampleView, w: Window) =
    if w.isNil:
        v.animation.cancel()
    else:
        w.addAnimation(v.animation)

registerSample "Animation", AnimationSampleView.new(newRect(0, 0, 100, 100))
