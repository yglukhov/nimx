import math
import macros

type LoopPattern* = enum
    lpStartToEndToStart
    lpStartToEnd
    lpEndToStart
    lpEndToStartToEnd

type TimingFunction = proc(time: float): float
type AnimationFunction = proc(progress: float)

type Animation* = ref object of RootObj
    startTime*: float
    loopDuration*: float
    pattern*: LoopPattern
    numberOfLoops*: int
    timingFunction*: TimingFunction
    onAnimate*: AnimationFunction
    finished*: bool
    completionHandler: proc()

proc newAnimation*(): Animation =
    result.new()
    result.numberOfLoops = -1
    result.loopDuration = 1.0
    result.pattern = lpStartToEnd

method tick*(a: Animation, curTime: float) =
    let duration = curTime - a.startTime
    var loopProgress = 1.0
    if a.numberOfLoops > 0 and duration >= a.numberOfLoops.float * a.loopDuration:
        a.finished = true
    else:
        let timeInLoop = duration mod a.loopDuration
        loopProgress = timeInLoop / a.loopDuration
        if not a.timingFunction.isNil:
            loopProgress = a.timingFunction(loopProgress)
    if not a.onAnimate.isNil:
        a.onAnimate(loopProgress)
    if a.finished and not a.completionHandler.isNil:
        a.completionHandler()

proc onComplete*(a: Animation, p: proc()) =
    a.completionHandler = p

# Bezier curves timing stuff.
# Taken from http://greweb.me/2012/02/bezier-curve-based-easing-functions-from-concept-to-implementation/
proc A(a1, a2: float): float = 1.0 - 3.0 * a2 + 3.0 * a1
proc B(a1, a2: float): float = 3.0 * a2 - 6.0 * a1
proc C(a1: float): float = 3.0 * a1

# Returns x(t) given t, x1, and x2, or y(t) given t, y1, and y2.
proc calcBezier(t, a1, a2: float): float = ((A(a1, a2) * t + B(a1, a2)) * t + C(a1)) * t

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

template nimx_setInterpolationAnimation*(a: Animation, ident: expr, fromVal, toVal: expr, body: stmt): stmt {.immediate.} =
    let fv = fromVal
    let tv = toVal
    a.onAnimate = proc(p: float) =
        let `ident` {.inject.} = interpolate(fv, tv, p)
        body

macro animate*(a: Animation, what: expr, how: stmt): stmt {.immediate.} =
    let ident = what[1]
    let fromVal = what[2][1]
    let toVal = what[2][2]
    result = newCall("nimx_setInterpolationAnimation", a, ident, fromVal, toVal, how)

# Value interpolation
proc animateValue*[T](fromValue, toValue: T, cb: proc(value: T)): AnimationFunction =
    result = proc(progress: float) =
        cb((toValue - fromValue) * progress)

