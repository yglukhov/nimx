import math

type LoopPattern* = enum
    lpStartToEndToStart
    lpStartToEnd
    lpEndToStart
    lpEndToStartToEnd


type Animation* = ref object of RootObj
    startTime*: float
    loopDuration*: float
    pattern*: LoopPattern
    numberOfLoops*: int
    timeFunction*: proc(progress: float): float
    onAnimate*: proc(progress: float)

proc newAnimation*(): Animation =
    result.new()
    result.numberOfLoops = -1
    result.loopDuration = 1.0
    result.pattern = lpStartToEnd

method tick*(a: Animation, curTime: float) =
    let duration = curTime - a.startTime
    let timeInLoop = duration mod a.loopDuration
    let loopProgress = timeInLoop / a.loopDuration
    let filteredProgress = if a.timeFunction.isNil:
            loopProgress # linear function
        else:
            a.timeFunction(loopProgress)
    if not a.onAnimate.isNil:
        a.onAnimate(filteredProgress)

