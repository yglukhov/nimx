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
        numberOfLoops*: int
        timingFunction*: TimingFunction
        onAnimate*: AnimationFunction
        finished*: bool
        cancelLoop: int # Loop at which animation was cancelled. -1 if not cancelled
        curLoop*: int
        tag*: string

        continueUntilEndOfLoopOnCancel*: bool
        loopProgressHandlers: seq[ProgressHandler]
        totalProgressHandlers: seq[ProgressHandler]
        lphIt, tphIt: int # Cursors for progressHandlers arrays

    MetaAnimation* = ref object of Animation
        animations*: seq[Animation]
        curIndex*: int
        parallelMode*: bool
        loopNum*: int

proc newAnimation*(): Animation =
    result.new()
    result.startTime = -1
    result.numberOfLoops = -1
    result.loopDuration = 1.0
    result.loopPattern = lpStartToEnd

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

proc removeHandlers*(a: Animation) =
    a.removeTotalProgressHandlers()
    a.removeLoopProgressHandlers()

method prepare*(a: Animation, startTime: float) {.base.} =
    a.finished = false
    a.startTime = startTime
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

proc tick*(a: Animation, curTime: float) =
    if a.pauseTime != 0: return
    let duration = curTime - a.startTime
    let currentLoop = a.currentLoopForTotalDuration(duration)
    var loopProgress = (duration mod a.loopDuration) / a.loopDuration
    if currentLoop > a.curLoop:
        if not a.loopProgressHandlers.isNil:
            processRemainingHandlersInLoop(a.loopProgressHandlers, a.lphIt, stopped=false)

    var totalProgress =
        if a.numberOfLoops > 0: duration / (float(a.numberOfLoops) * a.loopDuration)
        else: 0.0

    if a.cancelLoop >= 0:
        if not a.continueUntilEndOfLoopOnCancel:
            a.finished = true
        elif currentLoop > a.cancelLoop:
            a.finished = true
            loopProgress = 1.0

    if a.numberOfLoops >= 0 and currentLoop >= a.numberOfLoops:

        a.finished = true
        loopProgress = 1.0
        totalProgress = 1.0

    let oldLoop = a.curLoop
    a.curLoop = currentLoop

    if not a.onAnimate.isNil:
        var curvedProgress = loopProgress
        if a.loopPattern == lpStartToEndToStart:
            curvedProgress *= 2
            if curvedProgress >= 1.0: curvedProgress = 2 - curvedProgress
        elif a.loopPattern == lpEndToStart:
            curvedProgress = 1.0 - curvedProgress
        if not a.timingFunction.isNil:
            curvedProgress = a.timingFunction(curvedProgress)
        a.onAnimate(curvedProgress)

    if not a.finished:
        if not a.loopProgressHandlers.isNil: processHandlers(a.loopProgressHandlers, a.lphIt, loopProgress)
    if not a.totalProgressHandlers.isNil: processHandlers(a.totalProgressHandlers, a.tphIt, totalProgress)

    if a.finished:
        if currentLoop == oldLoop and not a.loopProgressHandlers.isNil and a.lphIt < a.loopProgressHandlers.len:
            processRemainingHandlersInLoop(a.loopProgressHandlers, a.lphIt, stopped=true)
        if not a.totalProgressHandlers.isNil and a.tphIt < a.totalProgressHandlers.len:
            processRemainingHandlersInLoop(a.totalProgressHandlers, a.tphIt, stopped=true)

proc cancel*(a: Animation) =
    if a.startTime < 0:
        logi "Animation was not played before cancelling!"
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

proc bezierTimingFunction*(x1, y1, x2, y2: float): TimingFunction =
    result = proc(p: float): float =
        if x1 == y1 and x2 == y2: return p # linear

        # Newton raphson iteration
        var aGuessT = p
        for i in 0 .. < 4:
            var currentSlope = getSlope(aGuessT, x1, x2)
            if currentSlope == 0.0: break
            var currentX = calcBezier(aGuessT, x1, x2) - p
            aGuessT -= currentX / currentSlope

        return calcBezier(aGuessT, y1, y2)

template interpolate*[T](fromValue, toValue: T, p: float): T = fromValue + (toValue - fromValue) * p
template interpolate*(fromValue, toValue: SomeInteger, p: float): auto = fromValue + type(fromValue)(float(toValue - fromValue) * p)

template setInterpolationAnimation(a: Animation, ident: expr, fromVal, toVal: expr, body: stmt): stmt {.immediate.} =
    let fv = fromVal
    let tv = toVal
    a.onAnimate = proc(p: float) =
        let `ident` {.inject.} = interpolate(fv, tv, p)
        body

macro animate*(a: Animation, what: expr, how: stmt): stmt {.immediate.} =
    let ident = what[1]
    let fromVal = what[2][1]
    let toVal = what[2][2]
    result = newCall(bindsym"setInterpolationAnimation", a, ident, fromVal, toVal, how)

# Value interpolation
proc animateValue*[T](fromValue, toValue: T, cb: proc(value: T)): AnimationFunction =
    result = proc(progress: float) =
        cb((toValue - fromValue) * progress)

proc chainOnAnimate*(a: Animation, oa: proc(p: float)) =
    if a.onAnimate.isNil:
        a.onAnimate = oa
    else:
        let oldProc = a.onAnimate
        a.onAnimate = proc(p: float) =
            oldProc(p)
            oa(p)

proc pause*(a: Animation) =
    if a.pauseTime == 0:
        a.pauseTime = epochTime()

proc resume*(a: Animation) =
    if a.pauseTime != 0:
        a.startTime += epochTime() - a.pauseTime
        a.pauseTime = 0

proc newMetaAnimation*(anims: varargs[Animation]): MetaAnimation =
    result.new()
    result.startTime = -1
    result.numberOfLoops = -1
    result.loopPattern = lpStartToEnd
    result.animations = @anims
    result.curIndex = -1
    result.loopDuration = 1.0

    var a = result
    result.onAnimate = proc(p: float) =
        a.finished = false
        if a.animations.len <= 0: return
        let ep = epochTime()

        if not a.parallelMode:
            if a.curIndex == -1 or (a.curIndex < a.animations.len - 1 and a.animations[a.curIndex].finished):
                inc a.curIndex
                a.animations[a.curIndex].prepare(ep)
            elif a.curIndex == a.animations.len - 1 and a.animations[a.curIndex].finished:
                if a.numberOfLoops == -1 or a.loopNum < a.numberOfLoops - 1:
                    a.curIndex = -1
                    inc a.loopNum
                else:
                    a.finished = true
            else:
                a.animations[a.curIndex].tick(ep)
        else:
            var anims_finished = true

            if a.curIndex == -1:
                for anim in a.animations:
                    anim.prepare(ep)
                a.curIndex = 0

            for anim in a.animations:
                if not anim.finished:
                    anims_finished = false
                    break

            if not anims_finished:
                for anim in a.animations:
                    if not anim.finished:
                        anim.tick(ep)
            else:
                if a.numberOfLoops == -1 or a.loopNum < a.numberOfLoops - 1:
                    a.curIndex = -1
                    inc a.loopNum
                else:
                    a.finished = true

method prepare*(a: MetaAnimation, startTime: float) =
    a.finished = false
    a.startTime = startTime
    a.lphIt = 0
    a.tphIt = 0
    a.cancelLoop = -1
    a.curLoop = 0
    a.curIndex = -1
    a.loopNum = 0

when isMainModule:
    proc emulateAnimationRun(a: Animation, startTime, endTime, fps: float): float =
        var curTime = startTime
        a.prepare(startTime)
        let timeStep = 1.0 / fps
        while true:
            a.tick(curTime)
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