import math
import macros
import algorithm

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

type Animation* = ref object of RootObj
    startTime*: float
    loopDuration*: float
    loopPattern*: LoopPattern
    numberOfLoops*: int
    timingFunction*: TimingFunction
    onAnimate*: AnimationFunction
    finished*: bool
    cancelLoop: int # Loop at which animation was cancelled. -1 if not cancelled
    curLoop: int

    continueUntilEndOfLoopOnCancel*: bool
    loopProgressHandlers: seq[ProgressHandler]
    totalProgressHandlers: seq[ProgressHandler]
    lphIt, tphIt: int # Cursors for progressHandlers arrays

proc newAnimation*(): Animation =
    result.new()
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

proc prepare*(a: Animation, startTime: float) =
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
        if currentLoop == a.curLoop and not a.loopProgressHandlers.isNil and a.lphIt < a.loopProgressHandlers.len:
            processRemainingHandlersInLoop(a.loopProgressHandlers, a.lphIt, stopped=true)
        if not a.totalProgressHandlers.isNil and a.tphIt < a.totalProgressHandlers.len:
            processRemainingHandlersInLoop(a.totalProgressHandlers, a.tphIt, stopped=true)
    a.curLoop = currentLoop

proc cancel*(a: Animation) = a.cancelLoop = a.curLoop
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
