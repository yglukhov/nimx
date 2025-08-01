
import view, animation, context, font, composition, image, notification_center,
  mini_profiler, portable_gl, drag_and_drop
import times, tables
import kiwi
export view

# Window type is defined in view module

#TODO: Window size has two notions. Think about it.

const DEFAULT_RUNNER = 0
const AW_FOCUS_ENTER* = "AW_FOCUS_ENTER"
const AW_FOCUS_LEAVE* = "AW_FOCUS_LEAVE"

method `title=`*(w: Window, t: string) {.base, gcsafe.} = discard
method title*(w: Window): string {.base, gcsafe.} = ""

method fullscreenAvailable*(w: Window): bool {.base.} = false
method fullscreen*(w: Window): bool {.base.} = false
method `fullscreen=`*(w: Window, v: bool) {.base.} = discard

# Bug 2488. Can not use {.global.} for JS target.
var lastTime = epochTime()
var lastFrame = 0.0
var totalAnims = 0

var fps {.threadvar.}: ProfilerDataSource[int]

proc updateFps() {.inline.} =
  let curTime = epochTime()
  let deltaTime = curTime - lastTime
  lastFrame = (lastFrame * 0.9 + deltaTime * 0.1)
  if fps.isNil:
    fps = sharedProfiler().newDataSource(int, "FPS")
  fps.value = (1.0 / lastFrame).int
  lastTime = curTime

when false:
  proc getTextureMemory(): int =
    var memory = 0.int
    var selfImages = findCachedResources[SelfContainedImage]()
    for img in selfImages:
      memory += int(img.size.width * img.size.height)

    memory = int(4 * memory / 1024 / 1024)
    return memory


method show*(w: Window) {.base, gcsafe.} = discard
method hide*(w: Window) {.base, gcsafe.} = discard

proc updateWindowLayout*(w: Window) =
  w.needsLayout = false
  w.layoutSolver.updateVariables()
  let oldSz = newSize(w.layout.vars.width.value, w.layout.vars.height.value)
  w.recursiveUpdateLayout(zeroPoint)
  let newSz = newSize(w.layout.vars.width.value, w.layout.vars.height.value)
  if newSz != oldSz:
    discard # TODO: update window size
  # echo w.dump() do(v: View) -> string:
  #   let name = if v.name.len != 0: " (" & v.name & "): " else: ": "
  #   v.className & name & $v.frame


method onResize*(w: Window, newSize: Size) {.base, gcsafe.} =
  w.layoutSolver.suggestValue(w.layout.vars.width, newSize.width)
  w.layoutSolver.suggestValue(w.layout.vars.height, newSize.height)
  w.updateWindowLayout()

method drawWindow*(w: Window) {.base, gcsafe.} =
  if w.needsLayout:
    w.updateWindowLayout()

  w.needsDisplay = false

  w.recursiveDrawSubviews()
  let c = currentContext()

  let profiler = sharedProfiler()
  if profiler.enabled:
    updateFps()
    profiler["Overdraw"] = GetOverdrawValue()
    profiler["DIPs"] = GetDIPValue()
    profiler["Animations"] = totalAnims

    const fontSize = 14
    const profilerWidth = 110
    var font = systemFont()
    let old_size = font.size
    font.size = fontSize
    var rect = newRect(w.frame.width - profilerWidth, 5, profilerWidth - 5, Coord(profiler.len) * font.height)
    c.fillColor = newGrayColor(1, 0.8)
    c.strokeWidth = 0
    c.drawRect(rect)

    var pt = newPoint(0, rect.y)
    c.fillColor = blackColor()
    for k, v in profiler:
      pt.x = w.frame.width - profilerWidth
      c.drawText(font, pt, k & ": " & v)
      pt.y = pt.y + fontSize
    font.size = old_size
  ResetOverdrawValue()
  ResetDIPValue()

  let dc = currentDragSystem()
  if not dc.pItem.isNil:
    var rect = newRect(0, 0, 20, 20)
    rect.origin += currentDragSystem().itemPosition

    if not dc.image.isNil:
      rect.size = dc.image.size
      c.drawImage(dc.image, rect)
    else:
      c.fillColor = newColor(0.0, 1.0, 0.0, 0.8)
      c.drawRect(rect)

method draw*(w: Window, rect: Rect) =
  let c = currentContext()
  let gl = c.gl
  if w.mActiveBgColor != w.backgroundColor:
    gl.clearColor(w.backgroundColor.r, w.backgroundColor.g, w.backgroundColor.b, w.backgroundColor.a)
    w.mActiveBgColor = w.backgroundColor
  gl.clear(gl.COLOR_BUFFER_BIT or gl.STENCIL_BUFFER_BIT or gl.DEPTH_BUFFER_BIT)

method animationStateChanged*(w: Window, state: bool) {.base.} = discard

proc isAnimationEnabled*(w: Window): bool = w.mAnimationEnabled

proc enableAnimation*(w: Window, flag: bool) =
  if w.mAnimationEnabled != flag:
    w.mAnimationEnabled = flag
    w.animationStateChanged(flag)

method startTextInput*(w: Window, r: Rect) {.base, gcsafe.} = discard
method stopTextInput*(w: Window) {.base, gcsafe.} = discard

proc runAnimations*(w: Window) =
  # New animations can be added while in the following loop. They will
  # have to be ticked on the next frame.
  var prevAnimsCount = totalAnims
  totalAnims = 0
  if not w.isNil:

    var index = 0
    let runnersLen = w.animationRunners.len

    while index < runnersLen:
      if index < w.animationRunners.len:
        let runner = w.animationRunners[index]
        totalAnims += runner.animations.len
        runner.update()
      inc index

    if totalAnims > 0:
      w.needsDisplay = true

  if prevAnimsCount == 0 and totalAnims >= 1:
    w.enableAnimation(true)
  elif prevAnimsCount >= 1 and totalAnims == 0:
    w.enableAnimation(false)

proc addAnimationRunner*(w: Window, ar: AnimationRunner)=
  if not w.isNil:
    if not (ar in w.animationRunners):
      w.animationRunners.add(ar)

template animations*(w: Window): seq[Animation] = w.animationRunners[DEFAULT_RUNNER].animations

proc removeAnimationRunner*(w: Window, ar: AnimationRunner)=
  if not w.isNil:
    for idx, runner in w.animationRunners:
      if runner == ar:
        if idx == DEFAULT_RUNNER: break
        runner.onDelete()
        w.animationRunners.delete(idx)
        # if runner.animations.len > 0:
        #   w.animationRemoved( runner.animations.len )
        break

proc addAnimation*(w: Window, a: Animation) =
  if not w.isNil:
    w.animationRunners[DEFAULT_RUNNER].pushAnimation(a)
    when defined(ios):
      # TODO: This is a quick fix for iOS animation issue. Should be researched more carefully.
      if not w.mAnimationEnabled:
        w.enableAnimation(true)

proc onFocusChange*(w: Window, inFocus: bool)=

  if inFocus:
    sharedNotificationCenter().postNotification(AW_FOCUS_ENTER)
  else:
    sharedNotificationCenter().postNotification(AW_FOCUS_LEAVE)

var newWindow* {.threadvar.}: proc(r: Rect): Window {.gcsafe.}
var newFullscreenWindow* {.threadvar.}: proc(): Window {.gcsafe.}
var newWindowWithNative* {.threadvar.}: proc(handle: pointer, r: Rect): Window {.gcsafe.}
var newFullscreenWindowWithNative* {.threadvar.}: proc(handle: pointer): Window {.gcsafe.}

method init*(w: Window) =
  procCall w.View.init()
  w.window = w
  w.needsDisplay = true
  w.mCurrentTouches = newTable[int, View]()
  w.mouseOverListeners = @[]
  w.animationRunners = @[]
  w.pixelRatio = 1.0
  let s = newSolver()
  w.layoutSolver = s
  s.addConstraint(w.layout.vars.x == 0)
  s.addConstraint(w.layout.vars.y == 0)
  s.addEditVariable(w.layout.vars.width, STRONG)
  s.addEditVariable(w.layout.vars.height, STRONG)

  # s.suggestValue(w.layout.vars.width, frame.width)
  # s.suggestValue(w.layout.vars.height, frame.height)

  w.backgroundColor = newGrayColor(0.93, 0)
  w.mActiveBgColor.r = -123 # Any invalid color

  #default animation runner for window
  w.addAnimationRunner(newAnimationRunner())

method enterFullscreen*(w: Window) {.base.} = discard
method exitFullscreen*(w: Window) {.base.} = discard
method isFullscreen*(w: Window): bool {.base.} = discard

proc toggleFullscreen*(w: Window) =
  if w.isFullscreen:
    w.exitFullscreen()
  else:
    w.enterFullscreen()

var gcRequested* = false
template requestGCFullCollect*() =
  gcRequested = true

registerClass(Window)
