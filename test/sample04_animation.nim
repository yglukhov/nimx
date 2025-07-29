import math # for PI
import sample_registry
import nimx / [ view, context, animation, window, button, progress_indicator, layout ]

type AnimationSampleView = ref object of View
  rotation: Coord
  animation: Animation

method init*(v: AnimationSampleView, r: Rect) =
  procCall v.View.init(r)
  v.animation = newAnimation()

  v.makeLayout:
    - Button as startStopButton:
      title: "Stop"
      leading == super + 20
      top == super + 20
      width == 70
      height == 50
      onAction:
        if v.animation.finished:
          v.window.addAnimation(v.animation)
          startStopButton.title = "Stop"
        else:
          v.animation.cancel()
    - Button as playPauseButton:
      title: "Pause"
      leading == prev.trailing + 20
      top == prev
      size == prev
      onAction:
        if playPauseButton.title == "Pause":
          v.animation.pause()
          playPauseButton.title = "Resume"
        else:
          v.animation.resume()
          playPauseButton.title = "Pause"

    - ProgressIndicator as progressBar:
      leading == prev.trailing + 20
      top == prev
      width == 90
      height == 20

  v.animation.timingFunction = bezierTimingFunction(0.53,-0.53,0.38,1.52)
  v.animation.onAnimate = proc(p: float) =
    v.rotation = p * PI * 2
  v.animation.loopDuration = 2.0
  v.animation.onComplete do():
    startStopButton.title = "Start"
  #v.animation.numberOfLoops = 2

  # Loop progress handlers are called when animation reaches specified loop progress.
  v.animation.addLoopProgressHandler 1.0, false, proc() =
    progressBar.value = 1.0

  v.animation.addLoopProgressHandler 0.5, false, proc() =
    progressBar.value = 0.5

  v.animation.continueUntilEndOfLoopOnCancel = true

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
