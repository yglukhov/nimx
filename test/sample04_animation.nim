import math # for PI
import sample_registry
import nimx / [ view, context, animation, window, button, progress_indicator ]

type AnimationSampleView = ref object of View
    rotation: Coord
    animation: Animation

method init*(v: AnimationSampleView, gfx: GraphicsContext, r: Rect) =
    procCall v.View.init(gfx, r)
    v.animation = newAnimation()

    # Start/Stop button
    let startStopButton = newButton(gfx, newRect(20, 20, 50, 50))
    startStopButton.title = "Stop"
    startStopButton.onAction do():
        if v.animation.finished:
            v.window.addAnimation(v.animation)
            startStopButton.title = "Stop"
        else:
            v.animation.cancel()
    v.addSubview(startStopButton)

    v.animation.timingFunction = bezierTimingFunction(0.53,-0.53,0.38,1.52)
    v.animation.onAnimate = proc(p: float) =
        v.rotation = p * PI * 2
    v.animation.loopDuration = 2.0
    v.animation.onComplete do():
        startStopButton.title = "Start"
    #v.animation.numberOfLoops = 2

    let playPauseButton = newButton(gfx, newRect(80, 20, 70, 50))
    playPauseButton.title = "Pause"
    playPauseButton.onAction do():
        if playPauseButton.title == "Pause":
            v.animation.pause()
            playPauseButton.title = "Resume"
        else:
            v.animation.resume()
            playPauseButton.title = "Pause"
    v.addSubview(playPauseButton)


    let progressBar = ProgressIndicator.new(gfx, newRect(160, 20, 90, 20))
    v.addSubview(progressBar)

    # Loop progress handlers are called when animation reaches specified loop progress.
    v.animation.addLoopProgressHandler 1.0, false, proc() =
        progressBar.value = 1.0

    v.animation.addLoopProgressHandler 0.5, false, proc() =
        progressBar.value = 0.5

    v.animation.continueUntilEndOfLoopOnCancel = true

method draw(v: AnimationSampleView, r: Rect) =
    template c: untyped = v.gfx
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

    c.strokeWidth = 10
    c.strokeColor = blackColor()
    c.fillColor = clearColor()
    c.drawArc(newPoint(100, 300), 50, v.rotation, v.rotation + Pi / 2)

method viewWillMoveToWindow*(v: AnimationSampleView, w: Window) =
    if w.isNil:
        v.animation.cancel()
    else:
        w.addAnimation(v.animation)

registerSample(AnimationSampleView, "Animation")
