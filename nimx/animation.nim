import math
import macros
import algorithm
import system_logger
import times

type LoopPattern* = enum
    lpStartToEndToStart
    lpStartToEnd
    lpEndToStart
    lpEndToStartToEnd

type CancelBehavior* = enum
    cbNoJump
    cbJumpToStart
    cbJumpToEnd
    cbContinueUntilEndOfLoop

type TimingFunction = proc(time: float): float
type AnimationFunction = proc(progress: float)

type ProgressHandler = object
    handler: proc()
    progress: float
    callIfCancelled: bool

type
    Animation* = ref object of RootObj
        startTime*: float
        pauseTime*: float
        loopDuration*: float
        loopPattern*: LoopPattern
        cancelBehavior*: CancelBehavior
        numberOfLoops*: int
        timingFunction*: TimingFunction
        onAnimate*: AnimationFunction
        finished*: bool
        cancelLoop: int # Loop at which animation was cancelled. -1 if not cancelled
        curLoop*: int
        tag*: string

        loopProgressHandlers: seq[ProgressHandler]
        totalProgressHandlers: seq[ProgressHandler]
        lphIt, tphIt: int # Cursors for progressHandlers arrays

    MetaAnimation* = ref object of Animation
        animations*: seq[Animation]
        mParallelMode: bool
        mOnAnimate: AnimationFunction
        mAnimationsHandlers: seq[ProgressHandler]
        aphIt: int # cursor for animationsHandlers array

proc init*(a: Animation) =
    a.numberOfLoops = -1
    a.loopDuration = 1.0
    a.cancelBehavior = cbNoJump
    a.loopPattern = lpStartToEnd

proc newAnimation*(): Animation =
    result.new()
    result.init()

proc addHandler(s: var seq[ProgressHandler], ph: ProgressHandler) =
    if s.isNil: s = newSeq[ProgressHandler]()
    s.insert(ph,
        s.lowerBound(ph, proc (a, b: ProgressHandler): int = cmp(a.progress, b.progress)))

proc addLoopProgressHandler*(a: Animation, progress: float, callIfCancelled: bool, handler: proc()) =
    addHandler(a.loopProgressHandlers, ProgressHandler(handler: handler, progress: progress,
        callIfCancelled: callIfCancelled))

proc addTotalProgressHandler*(a: Animation, progress: float, callIfCancelled: bool, handler: proc()) =
    addHandler(a.totalProgressHandlers, ProgressHandler(handler: handler, progress: progress,
        callIfCancelled: callIfCancelled))

proc removeTotalProgressHandlers*(a: Animation) =
    if not a.totalProgressHandlers.isNil: a.totalProgressHandlers.setLen(0)

proc removeLoopProgressHandlers*(a: Animation) =
    if not a.loopProgressHandlers.isNil: a.loopProgressHandlers.setLen(0)

proc `continueUntilEndOfLoopOnCancel=`*(a: Animation, bval: bool)=
    if bval:
        a.cancelBehavior = cbContinueUntilEndOfLoop
    else:
        a.cancelBehavior = cbNoJump

proc removeHandlers*(a: Animation) =
    a.removeTotalProgressHandlers()
    a.removeLoopProgressHandlers()

method prepare*(a: Animation, st: float) {.base.} =
    a.finished = false
    a.startTime = st
    a.lphIt = 0
    a.tphIt = 0
    a.cancelLoop = -1
    a.curLoop = 0

template currentLoopForTotalDuration(a: Animation, d: float): int = int(d / a.loopDuration)

proc processHandlers(handlers: openarray[ProgressHandler], it: var int, progress: float) =
    while it < handlers.len:
        if handlers[it].progress <= progress:
            handlers[it].handler()
            inc it
        else:
            break

proc processRemainingHandlersInLoop(handlers: openarray[ProgressHandler], it: var int, stopped: bool) =
    while it < handlers.len:
        if not stopped or handlers[it].callIfCancelled:
            handlers[it].handler()
        inc it
    it = 0

proc curvedProgress(a: Animation, p: float): float =
    var curvedProgress = p
    if a.loopPattern == lpStartToEndToStart:
        curvedProgress *= 2
        if curvedProgress >= 1.0: curvedProgress = 2 - curvedProgress
    elif a.loopPattern == lpEndToStart:
        curvedProgress = 1.0 - curvedProgress
    if not a.timingFunction.isNil:
        curvedProgress = a.timingFunction(curvedProgress)
    result = curvedProgress

method onProgress*(a: Animation, p: float) {.base.} =
    if not a.onAnimate.isNil:
        a.onAnimate(a.curvedProgress(p))

proc loopProgress(a: Animation, t: float): float=
    let duration = t - a.startTime
    doAssert(duration > -0.0001)
    a.curLoop = a.currentLoopForTotalDuration(duration)
    result = (duration mod a.loopDuration) / a.loopDuration

proc totalProgress(a: Animation, t: float): float=
    result =
        if a.numberOfLoops > 0: (t - a.startTime) / (float(a.numberOfLoops) * a.loopDuration)
        else: 0.0

method checkHandlers(a: Animation, oldLoop: int, lp, tp: float) {.base.} =
    if a.curLoop > oldLoop:
        if not a.loopProgressHandlers.isNil:
            processRemainingHandlersInLoop(a.loopProgressHandlers, a.lphIt, stopped=false)

    if not a.finished:
        if not a.loopProgressHandlers.isNil: processHandlers(a.loopProgressHandlers, a.lphIt, lp)
        if not a.totalProgressHandlers.isNil: processHandlers(a.totalProgressHandlers, a.tphIt, tp)

    if a.finished:
        if a.curLoop == oldLoop and not a.loopProgressHandlers.isNil and a.lphIt < a.loopProgressHandlers.len:
            processRemainingHandlersInLoop(a.loopProgressHandlers, a.lphIt, stopped=true)
        if not a.totalProgressHandlers.isNil and a.tphIt < a.totalProgressHandlers.len:
            processRemainingHandlersInLoop(a.totalProgressHandlers, a.tphIt, stopped=true)

proc tick*(a: Animation, t: float) =
    if a.pauseTime != 0: return

    let oldLoop = a.curLoop
    var loopProgress = a.loopProgress(t)
    var totalProgress = a.totalProgress(t)

    if a.cancelLoop >= 0:
        if a.cancelBehavior != cbContinueUntilEndOfLoop:
            a.finished = true
            if a.cancelBehavior == cbJumpToEnd:
                loopProgress = 1.0
            elif a.cancelBehavior == cbJumpToStart:
                loopProgress = 0.0
        elif a.curLoop > a.cancelLoop:
            a.finished = true
            loopProgress = 1.0

    if a.numberOfLoops >= 0 and a.curLoop >= a.numberOfLoops:
        a.finished = true
        loopProgress = 1.0
        totalProgress = 1.0

    a.onProgress(loopProgress)
    a.checkHandlers(oldLoop, loopProgress, totalProgress)

proc cancel*(a: Animation) =
    a.cancelLoop = a.curLoop

proc isCancelled*(a: Animation): bool = a.cancelLoop != -1

proc onComplete*(a: Animation, p: proc()) =
    a.addTotalProgressHandler(1.0, true, p)

# Bezier curves timing stuff.
# Taken from http://greweb.me/2012/02/bezier-curve-based-easing-functions-from-concept-to-implementation/
template A(a1, a2: float): float = 1.0 - 3.0 * a2 + 3.0 * a1
template B(a1, a2: float): float = 3.0 * a2 - 6.0 * a1
template C(a1: float): float = 3.0 * a1

# Returns x(t) given t, x1, and x2, or y(t) given t, y1, and y2.
template calcBezier(t, a1, a2: float): float = ((A(a1, a2) * t + B(a1, a2)) * t + C(a1)) * t

# Returns dx/dt given t, x1, and x2, or dy/dt given t, y1, and y2.
proc getSlope(t, a1, a2: float): float = 3.0 * A(a1, a2) * t * t + 2.0 * B(a1, a2) * t + C(a1)

proc bezierXForProgress*(x1, y1, x2, y2, p: float): float {.inline.} =
    if x1 == y1 and x2 == y2: return p # linear

    # Newton raphson iteration
    var aGuessT = p
    for i in 0 .. < 4:
        var currentSlope = getSlope(aGuessT, x1, x2)
        if currentSlope == 0.0: break
        var currentX = calcBezier(aGuessT, x1, x2) - p
        aGuessT -= currentX / currentSlope

    return calcBezier(aGuessT, y1, y2)

proc bezierTimingFunction*(x1, y1, x2, y2: float): TimingFunction =
    result = proc(p: float): float =
        bezierXForProgress(x1, y1, x2, y2, p)

template interpolate*[T](fromValue, toValue: T, p: float): T = fromValue + (toValue - fromValue) * p
template interpolate*(fromValue, toValue: SomeInteger, p: float): auto = fromValue + type(fromValue)(float(toValue - fromValue) * p)

when defined(js): ## workaround for int64 in javascript
    template interpolate*(fromValue, toValue: int64, p: float): int64 = fromValue + int(float(toValue - fromValue) * p)

template setInterpolationAnimation(a: Animation, ident: untyped, fromVal, toVal: untyped, body: untyped): typed =
    let fv = fromVal
    let tv = toVal
    a.onAnimate = proc(p: float) =
        let ident {.inject, hint[XDeclaredButNotUsed]: off.} = interpolate(fv, tv, p)
        body

macro animate*(a: Animation, what: untyped, how: untyped): typed =
    let ident = what[1]
    let fromVal = what[2][1]
    let toVal = what[2][2]
    result = newCall(bindsym"setInterpolationAnimation", a, ident, fromVal, toVal, how)

# Value interpolation
proc animateValue*[T](fromValue, toValue: T, cb: proc(value: T)): AnimationFunction =
    result = proc(progress: float) =
        cb((toValue - fromValue) * progress)

proc chainOnAnimate*(a: Animation, oa: proc(p: float)) {.deprecated.} = #use addOnAnimate instead of this proc
    if a.onAnimate.isNil:
        a.onAnimate = oa
    else:
        let oldProc = a.onAnimate
        a.onAnimate = proc(p: float) =
            oldProc(p)
            oa(p)

proc addOnAnimate*(a: Animation, oa: proc(p: float)): Animation =
    result.new()
    result.numberOfLoops = a.numberOfLoops
    result.loopPattern = a.loopPattern
    result.loopDuration = a.loopDuration
    result.cancelBehavior = a.cancelBehavior
    result.timingFunction = a.timingFunction
    result.loopProgressHandlers = a.loopProgressHandlers
    result.totalProgressHandlers = a.totalProgressHandlers

    if a.onAnimate.isNil:
        result.onAnimate = oa
    else:
        let oldProc = a.onAnimate
        result.onAnimate = proc(p: float) =
            oldProc(p)
            oa(p)

proc pause*(a: Animation) =
    a.pauseTime = epochTime()

proc resume*(a: Animation) =
    if a.pauseTime != 0:
        a.startTime += epochTime() - a.pauseTime
        a.pauseTime = 0

## ---------------------------------------- META ANIMATION'S ---------------------------------------- ##

proc addAnimationOnProgress(m: MetaAnimation, progress: float, a: Animation) =
    addHandler m.mAnimationsHandlers, ProgressHandler(
        handler: (
            proc() =
                a.prepare(epochTime())
            ),
        progress: progress,
        callIfCancelled: false)

proc resetAnimationsHandlers(m: MetaAnimation)=
    if not m.mAnimationsHandlers.isNil: m.mAnimationsHandlers.setLen(0)

proc `parallelMode=`*(m: MetaAnimation, val: bool)=
    m.mParallelMode = val
    m.resetAnimationsHandlers()
    m.loopDuration = 0.0
    if val:
        for a in m.animations:
            m.loopDuration = max(a.loopDuration * a.numberOfLoops.float, m.loopDuration)
            m.addAnimationOnProgress(0.0, a)
    else:
        for a in m.animations:
            m.loopDuration += a.loopDuration * a.numberOfLoops.float

        var cp = 0.0
        for a in m.animations:
            m.addAnimationOnProgress(cp, a)
            cp += a.loopDuration / m.loopDuration
    echo "parallelMode ch ", val, " loopDuration ", m.loopDuration

proc parallelMode*(m: MetaAnimation): bool = m.mParallelMode

proc newMetaAnimation*(anims: varargs[Animation]): MetaAnimation =
    result.new()
    let m = result
    m.animations = @anims
    m.parallelMode = false
    m.numberOfLoops = -1
    m.loopPattern = lpStartToEnd

method prepare*(m: MetaAnimation, t: float)=
    m.finished = m.animations.len == 0
    m.startTime = t
    m.lphIt = 0
    m.tphIt = 0
    m.cancelLoop = -1
    m.curLoop = 0

method onProgress*(m: MetaAnimation, p: float) =
    let cp = m.curvedProgress(p)
    for i, a in m.animations:
        if a.startTime != 0.0 and a.pauseTime == 0.0:
            let sp = 1.0 - (m.startTime - m.loopDuration * m.curLoop.float) / (a.startTime - m.loopDuration * m.curLoop.float)
            let sc = (a.loopDuration * (a.curLoop + 1).float) / m.loopDuration
            let ep = sp + sc

            let t = a.startTime + (a.curLoop + 1).float * a.loopDuration * cp

            # if p >= sp and p <= ep:
            a.tick(t)

method checkHandlers(m: MetaAnimation, oldLoop: int, lp, tp: float) =
    if m.curLoop > oldLoop:
        if not m.mAnimationsHandlers.isNil:
            processRemainingHandlersInLoop(m.mAnimationsHandlers, m.aphIt, stopped=false)

    if not m.finished:
        if not m.mAnimationsHandlers.isNil: processHandlers(m.mAnimationsHandlers, m.aphIt, lp)

    procCall m.Animation.checkHandlers(oldLoop, lp, tp)

when isMainModule:
    proc emulateAnimationRun(a: Animation, startTime, endTime, fps: float): float =
        var curTime = startTime
        a.prepare(startTime)
        let timeStep = 1.0 / fps
        while true:
            a.tick(timeStep)
            if a.finished: break
            curTime += timeStep
        result = curTime - startTime

    let a = newAnimation()
    a.loopDuration = 1.0
    a.numberOfLoops = 1

    var progresses = newSeq[float]()
    a.onAnimate = proc(p: float) =
        progresses.add(p)

    let timeTaken = a.emulateAnimationRun(5.0, 6.0, 60)

    doAssert(progresses[^1] == 1.0)

const PI_X2 = PI * 2.0

# when used to allow wrap all predefined timefunction in editors
when true:
    ## http://easings.net
    proc linear*(time: float): float =
        result = time
    ## -------------------------------------------------------------
    proc sineEaseIn*(time: float): float =
        result = -1 * cos(time * PI_X2) + 1

    proc sineEaseOut*(time: float): float =
        result = sin(time * PI_X2)

    proc sineEaseInOut*(time: float): float =
        result = -0.5 * (cos(PI * time) - 1)

    ## -------------------------------------------------------------
    proc quadEaseIn*(time: float): float =
        result = time * time

    proc quadEaseOut*(time: float): float =
        result = -1 * time * (time - 2)

    proc quadEaseInOut*(time: float): float =
        var var_time = time * 2
        if var_time < 1:
            result = 0.5 * var_time * var_time
        else:
            var_time -= 1.0
            result = -0.5 * (var_time * (var_time - 2) - 1)

    ## -------------------------------------------------------------
    proc cubicEaseIn*(time: float): float =
        result = time * time * time

    proc cubicEaseOut*(time: float): float =
        var var_time = time - 1
        result = var_time * var_time * var_time + 1

    proc cubicEaseInOut*(time: float): float =
        var var_time = time * 2
        if var_time < 1:
            result = 0.5 * var_time * var_time * var_time
        else:
            var_time -= 2
            result = 0.5 * (var_time * var_time * var_time + 2)

    ## -------------------------------------------------------------
    proc quartEaseIn*(time: float): float =
        result = time * time * time * time

    proc quartEaseOut*(time: float): float =
        var var_time = time - 1
        result = -(var_time * var_time * var_time * var_time - 1)

    proc quartEaseInOut*(time: float): float =
        var var_time = time * 2
        if var_time < 1:
            result = 0.5 * var_time * var_time * var_time * var_time
        else:
            var_time -= 2.0
            result = -0.5 * (var_time * var_time * var_time * var_time - 2)

    ## -------------------------------------------------------------
    proc quintEaseIn*(time: float): float =
        result = time * time * time * time * time

    proc quintEaseOut*(time: float): float =
        var var_time = time - 1
        result = var_time * var_time * var_time * var_time * var_time + 1

    proc quintEaseInOut*(time: float): float =
        var var_time = time * 2
        if var_time < 1:
            result = 0.5 * var_time * var_time * var_time * var_time * var_time
        else:
            var_time -= 2.0
            result = -0.5 * (var_time * var_time * var_time * var_time * var_time + 2)

    ## -------------------------------------------------------------
    proc expoEaseIn*(time: float): float =
        if time <= 0.0001:
            result = 0
        else:
            result = pow(2, 10 * (time/1 - 1)) - 1 * 0.001

    proc expoEaseOut*(time: float): float =
        if time >= 0.9999:
            result = 1.0
        else:
            result = -pow(2, -10 * time/1 ) + 1

    proc expoEaseInOut*(time: float): float =
        var var_time = time * 2
        if var_time < 1:
            result = 0.5 * pow(2, 10 * (var_time - 1))
        else:
            result = 0.5 * (-pow(2, -10 * (var_time - 1)) + 2)
    ## -------------------------------------------------------------

    proc circleEaseIn*(time: float): float =
        result = -(sqrt(1 - time * time) - 1)

    proc circleEaseOut*(time: float): float =
        var var_time = time - 1
        result = sqrt( 1 - var_time * var_time )

    proc circleEaseInOut*(time: float): float =
        var var_time = time * 2
        if var_time < 1:
            result = -0.5 * (sqrt(1 - var_time * var_time) - 1)
        else:
            result = 0.5 * (sqrt(1 - var_time * var_time) + 1)

    ## -------------------------------------------------------------
    proc elasticEaseIn*(time, period: float): float =
        if time <= 0.0001 or 0 >= 0.9999:
            result = time
        else:
            var s = period / 4
            var var_time = time - 1
            result = -pow(2, 10 * var_time) * sin((var_time - s) * PI_X2 / period)

    proc elasticEaseOut*(time, period: float): float =
        if time <= 0.0001 or 0 >= 0.9999:
            result = time
        else:
            var s = period / 4
            result = pow(2, -10 * time) * sin((time - s) * PI_X2 / period) + 1

    proc elasticEaseInOut*(time, period: float): float =
        if time <= 0.0001 or 0 >= 0.9999:
            result = time
        else:
            var var_time = time * 2 - 1
            var nPeriod: float
            if period == 0.0:
                nPeriod = 0.3 * 1.5
            else:
                nPeriod = period
            var s = nPeriod / 4
            if var_time < 0:
                result = -0.5 * pow(2, 10 * var_time) * sin((var_time - s) * PI_X2/nPeriod)
            else:
                result = pow(2, -10 * var_time) * sin((var_time - s) * PI_X2/nPeriod) * 0.5 + 1

    ## -------------------------------------------------------------
    proc backEaseIn*(time: float, overshoot: float = 1.70158): float =
        result = time * time * ((overshoot + 1) * time - overshoot)

    proc backEaseOut*(time: float, overshoot:float = 1.70158): float =
        var var_time = time - 1
        result = var_time * var_time * ((overshoot + 1) * var_time + overshoot) + 1

    proc backEaseInOut*(time: float, overshoot: float = 1.70158): float =
        var var_time = time * 2
        if var_time < 1:
            result = (var_time * var_time * (overshoot + 1) * var_time - overshoot) / 2
        else:
            var_time -= 2
            result = (var_time * var_time * ((overshoot + 1) * var_time + overshoot)) / 2 + 1

    ## -------------------------------------------------------------
    proc bounceTime(time: float): float =
        if time < 1 / 2.75:
            result = 7.5625 * time * time
        elif  time < 2 / 2.75:
            var var_time = time - 1.5/2.75
            result = 7.5625 * var_time * var_time + 0.75
        elif time < 2.5 / 2.75:
            var var_time = time - 2.25/2.75
            result = 7.5625 * var_time * var_time + 0.9375
        else:
            var var_time = time - 2.625/2.75
            result = 7.5265 * var_time * var_time + 0.984375

    proc bounceEaseIn*(time: float): float =
        result = 1 - bounceTime(1 - time)

    proc bounceEaseOut*(time: float): float =
        result = bounceTime(time)

    proc  bounceEaseInOut*(time: float): float =
        if time < 0.5:
            var var_time = time * 2
            result = ( 1 - bounceTime(1 - var_time)) * 0.5
        else:
            result = bounceTime(time * 2 - 1) * 0.5 + 0.5

    ## -------------------------------------------------------------
    proc quadraticIn*(time: float): float =
        result = pow(time, 2)

    proc quadraticOut*(time: float): float =
        result = -time * (time - 2)

    proc quadraticInOut*(time: float): float =
        var var_time = time * 2
        if  var_time < 1:
            result = var_time * var_time * 0.5
        else:
            var_time -= 1
            result = -0.5 * (var_time * (var_time - 2) - 1)
