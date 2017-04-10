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

    ComposeMarker* = ref object
        positionStart: float
        positionEnd: float
        onMarkerActive: proc(p:float)
        animation: Animation
        isActive: bool

    CompositAnimation* = ref object of Animation
        mMarkers: seq[ComposeMarker]
        mPrevDirection: bool

    MetaAnimation* = ref object of Animation
        animations*: seq[Animation]
        curIndex*: int
        parallelMode*: bool
        currentLoopPattern: LoopPattern

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
        if curvedProgress > 1.0: curvedProgress = 2 - curvedProgress
    elif a.loopPattern == lpEndToStart:
        curvedProgress = 1.0 - curvedProgress
    # elif a.loopPattern == lpEndToStartToEnd:
    #     curvedProgress *= 2
    #     if curvedProgress > 1.0:
    if not a.timingFunction.isNil:
        curvedProgress = a.timingFunction(curvedProgress)
    result = curvedProgress

method onProgress*(a: Animation, p: float) {.base.} =
    if not a.onAnimate.isNil:
        a.onAnimate(a.curvedProgress(p))

proc loopProgress(a: Animation, t: float): float=
    let duration = t - a.startTime
    doAssert(duration > -0.0001, $duration)
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

proc loopFinishCheck(a: Animation, lp, tp: var float)=
    if a.cancelLoop >= 0:
        if a.cancelBehavior != cbContinueUntilEndOfLoop:
            a.finished = true
            if a.cancelBehavior == cbJumpToEnd:
                lp = 1.0
            elif a.cancelBehavior == cbJumpToStart:
                lp = 0.0
        elif a.curLoop > a.cancelLoop:
            a.finished = true
            lp = 1.0

    if a.numberOfLoops >= 0 and a.curLoop >= a.numberOfLoops:
        a.finished = true
        lp = 1.0
        tp = 1.0

method tick*(a: Animation, t: float) =
    if a.pauseTime != 0: return

    let oldLoop = a.curLoop
    var loopProgress = a.loopProgress(t)
    var totalProgress = a.totalProgress(t)

    a.loopFinishCheck(loopProgress, totalProgress)

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
template interpolate*(fromValue, toValue: bool, p: float): bool =
    if p > 0.5:
        toValue
    else:
        fromValue
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

## ---------------------------------------- ANIMATIONS COMPOSE ---------------------------------------- ##

proc newComposeMarker*(pStart, pEnd: float, a: Animation): ComposeMarker=
    result.new()
    result.positionStart = pStart
    result.positionEnd = pEnd
    result.animation = a

proc addComposeMarker(m: CompositAnimation, marker: ComposeMarker) =
    marker.onMarkerActive = proc(p: float)=
        var a = marker.animation
        if marker.isActive:
            let diff = m.loopDuration * (p - marker.positionStart)
            a.prepare(epochTime() - diff)
        else:
            a.startTime = 0.0
            a.finished = false
            a.curLoop = 0

    m.mMarkers.add(marker)

proc newCompositAnimation*(duration: float, markers: varargs[ComposeMarker]): CompositAnimation =
    result.new()
    let m = result
    m.numberOfLoops = -1
    m.loopPattern = lpStartToEnd
    m.loopDuration = duration
    m.mMarkers = @[]

    for marker in markers:
        m.addComposeMarker(marker)

proc newCompositAnimation*(parallelMode: bool, anims: varargs[Animation]): CompositAnimation =
    var duration = 0.0
    var markers = newSeq[ComposeMarker]()
    if parallelMode:
        for a in anims:
            duration = max(a.loopDuration * a.numberOfLoops.float, duration)

        for a in anims:
            doAssert(a.numberOfLoops > 0)
            let pStart = 0.0
            let pEnd = (a.loopDuration * a.numberOfLoops.float) / duration
            markers.add(newComposeMarker(pStart, pEnd, a))

    else:
        for a in anims:
            duration += a.loopDuration * a.numberOfLoops.float

        var cp = 0.0
        for a in anims:
            doAssert(a.numberOfLoops > 0)
            let pStart = cp
            let pEnd = (a.loopDuration * a.numberOfLoops.float) / duration + pStart
            markers.add(newComposeMarker(pStart, pEnd, a))
            cp += (a.loopDuration * a.numberOfLoops.float) / duration

    result = newCompositAnimation(duration, markers)

method prepare*(m: CompositAnimation, t: float)=
    m.finished = false
    m.startTime = t
    m.lphIt = 0
    m.tphIt = 0
    m.cancelLoop = -1
    m.curLoop = 0

    for cm in m.mMarkers:
        cm.animation.startTime = 0.0
        cm.animation.cancelLoop = -1
        cm.isActive = false

iterator markersAtProgress(m: CompositAnimation, p: float, directionChanged: bool): ComposeMarker=
    for marker in m.mMarkers:
        var m: ComposeMarker
        if (p >= marker.positionStart and p < marker.positionEnd) and not directionChanged:
            if not marker.isActive:
                marker.isActive = true
                marker.onMarkerActive(p)
            m = marker

        elif marker.isActive:
            marker.isActive = false
            m = marker
            marker.onMarkerActive(p)

        if not m.isNil:
            yield m

proc isDirectionForward(m: CompositAnimation, p: float): bool =
    result = true
    if m.loopPattern == lpEndToStart:
        result = false
    elif m.loopPattern == lpStartToEndToStart and p > 0.5:
        result = false
    elif m.loopPattern == lpEndToStartToEnd and p < 0.5:
        result = false

method onProgress*(m: CompositAnimation, p: float) =
    let cp = m.curvedProgress(p)
    var directionForward = m.isDirectionForward(p)
    let directionChangedR = m.mPrevDirection and directionForward == false
    let directionChangedL = not m.mPrevDirection and directionForward

    for cm in m.markersAtProgress(cp, directionChangedR or directionChangedL):
        let a = cm.animation
        if not a.finished:
            var acp = cp - cm.positionStart

            if acp <= 0.0:
                acp = 0.0

            if directionChangedR:
                acp = 1.0
            elif directionChangedL:
                acp = 0.0

            var sc = m.loopDuration / (a.loopDuration * a.numberOfLoops.float)
            var ap = acp * a.numberOfLoops.float * sc
            let t = a.startTime + a.loopDuration * ap

            let oldLoop = a.curLoop
            var loopProgress = a.loopProgress(t)
            var totalProgress = a.totalProgress(t)
            a.loopFinishCheck(loopProgress, totalProgress)

            a.onProgress(loopProgress)

            loopProgress = if directionForward: loopProgress else: 1.0 - loopProgress
            totalProgress = if directionForward: totalProgress else: 1.0 - totalProgress
            if not cm.isActive:
                loopProgress = 1.0
                totalProgress = 1.0

            a.checkHandlers(oldLoop, loopProgress, totalProgress)

    m.mPrevDirection = directionForward


## -------------------------------- META ANIMATION --------------------------------- ##
proc newMetaAnimation*(anims: varargs[Animation]): MetaAnimation {.deprecated.} =
    result.new()
    result.numberOfLoops = -1
    result.loopPattern = lpStartToEnd
    result.animations = @anims
    result.curIndex = -1
    result.loopDuration = 1.0

proc nextIndex(a: MetaAnimation) =
    if a.loopPattern == lpStartToEnd:
        if a.currentLoopPattern != lpStartToEnd:
            a.curIndex = -1

        a.currentLoopPattern = lpStartToEnd
        inc a.curIndex

    elif a.loopPattern == lpEndToStart:
        if a.curIndex == -1 or a.currentLoopPattern != lpEndToStart:
            a.curIndex = a.animations.len

        a.currentLoopPattern = lpEndToStart
        dec a.curIndex

    elif a.loopPattern == lpStartToEndToStart:

        if a.curIndex == -1 and a.curLoop mod 2 == 0:
            a.currentLoopPattern = lpStartToEnd
        elif a.curIndex == -1 and a.currentLoopPattern != lpEndToStart:
            a.curIndex = a.animations.len
            a.currentLoopPattern = lpEndToStart

        if a.currentLoopPattern == lpStartToEnd:
            inc a.curIndex
        elif a.currentLoopPattern == lpEndToStart:
            dec a.curIndex

    elif a.loopPattern == lpEndToStartToEnd:

        if a.curIndex == -1 and a.curLoop mod 2 == 0:
            a.currentLoopPattern = lpEndToStart
            a.curIndex = a.animations.len
        elif a.curIndex == -1 and a.currentLoopPattern != lpStartToEnd:
            a.currentLoopPattern = lpStartToEnd

        if a.currentLoopPattern == lpStartToEnd:
            inc a.curIndex
        elif a.currentLoopPattern == lpEndToStart:
            dec a.curIndex


method prepare*(a: MetaAnimation, t: float)=
    a.finished = false
    a.startTime = t
    a.lphIt = 0
    a.tphIt = 0
    a.cancelLoop = -1
    a.curLoop = 0
    a.curIndex = -1

method tick*(a: MetaAnimation, t: float) =

    if a.pauseTime != 0 : return

    if a.animations.isNil or a.animations.len == 0:
        a.finished = true
        return

    var
        updateAnims: seq[Animation]
        animsFinished = true
        needPrepare = a.curIndex == -1 or (not a.parallelMode and a.animations[a.curIndex].startTime == 0)
        curTime = epochTime()

    if a.curIndex == -1:
        a.nextIndex()

    if a.parallelMode:
        updateAnims = a.animations
    else:
        updateAnims = @[]
        updateAnims.add(a.animations[a.curIndex])

    for anim in updateAnims:

        anim.loopPattern = a.currentLoopPattern

        if needPrepare:
            anim.prepare(curTime)

        if a.cancelLoop >= 0:
            anim.cancel()

        if not anim.finished:
            anim.tick(curTime)

        if not anim.finished: #if we call cancel, anim will be finished after tick
            animsFinished = false

    if animsFinished:
        if (a.curIndex < a.animations.len - 1 and a.currentLoopPattern == lpStartToEnd) or
            (a.curIndex > 0 and a.currentLoopPattern == lpEndToStart):
            a.nextIndex()
            a.animations[a.curIndex].startTime = 0

        elif ( (a.curIndex == a.animations.len - 1 and a.currentLoopPattern == lpStartToEnd) or
            (a.curIndex == 0 and a.currentLoopPattern == lpEndToStart) ) and (a.curLoop < a.numberOfLoops - 1 or a.numberOfLoops == -1):

            a.curIndex = -1
            inc a.curLoop

            if not a.loopProgressHandlers.isNil:
                processRemainingHandlersInLoop(a.loopProgressHandlers, a.lphIt, stopped=false)

        elif ((a.loopPattern == lpEndToStartToEnd or a.loopPattern == lpStartToEndToStart) and
            (a.curIndex == a.animations.len - 1 or a.curIndex == 0) and
            (a.curLoop < a.numberOfLoops * 2 - 1 or a.numberOfLoops == -1)):
            a.curIndex = -1
            inc a.curLoop

            if not a.loopProgressHandlers.isNil:
                processRemainingHandlersInLoop(a.loopProgressHandlers, a.lphIt, stopped=false)
        else:
            a.finished = true
            if not a.loopProgressHandlers.isNil and a.lphIt < a.loopProgressHandlers.len:
                processRemainingHandlersInLoop(a.loopProgressHandlers, a.lphIt, stopped=true)
            if not a.totalProgressHandlers.isNil and a.tphIt < a.totalProgressHandlers.len:
                processRemainingHandlersInLoop(a.totalProgressHandlers, a.tphIt, stopped=true)


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
