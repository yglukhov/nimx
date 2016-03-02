import times

when defined(js):
    type TimerID {.importc.} = ref object

    proc setInterval(p: proc(), timeout: float): TimerID {.importc.}
    proc setTimeout(p: proc(), timeout: float): TimerID {.importc.}
    proc clearInterval(t: TimerID) {.importc.}
    proc clearTimeout(t: TimerID) {.importc.}

else:
    import sdl2, sdl_perform_on_main_thread, tables

type Timer* = ref object
    callback: proc()
    timer: TimerID
    nextFireTime: float
    interval: float
    isPeriodic: bool
    isRescheduling: bool
    when not defined(js):
        id: int

when not defined(js):
    # Due to SDL timers are running on a separate thread there is no way to
    # safely pass pointers/references as timer context because there is no
    # way to tell which thread touches the context last and has to dispose it.
    # Solution to this is a global map of active timers.
    var allTimers = initTable[int, Timer]()

    proc deleteTimerFromSDL(t: Timer) =
        discard removeTimer(t.timer)
        t.timer = 0
        allTimers.del(t.id)
        t.id = 0

template isTimerValid(t: Timer): bool =
    when defined(js):
        not t.timer.isNil
    else:
        t.timer != 0

proc clear*(t: Timer) =
    if not t.isNil:
        if t.isTimerValid:
            when defined(js):
                if t.isPeriodic and not t.isRescheduling:
                    clearInterval(t.timer)
                else:
                    clearTimeout(t.timer)
                t.timer = nil
            else:
                t.deleteTimerFromSDL()
            t.nextFireTime = t.nextFireTime - epochTime()

template fireCallbackAux(t: Timer) =
    t.callback()
    if t.isPeriodic:
        t.nextFireTime = epochTime() + t.interval
        if t.isRescheduling:
            discard

when not defined(js):
    proc nextTimerId(): int =
        var idCounter {.global.} = 0
        inc idCounter
        result = idCounter

    proc timeoutThreadCallback(interval: uint32, data: pointer): uint32 {.cdecl.}

    proc fireCallback(data: pointer) {.cdecl.} =
        let t = allTimers.getOrDefault(cast[int](data))
        if not t.isNil:
            t.fireCallbackAux()
            if not t.isPeriodic:
                t.deleteTimerFromSDL()
            elif t.isRescheduling:
                t.deleteTimerFromSDL()
                t.id = nextTimerId()
                t.isRescheduling = false
                allTimers[t.id] = t
                t.timer = addTimer(uint32(t.interval * 1000), timeoutThreadCallback, cast[pointer](t.id))


    # Nim is hostile when it's callbacks are called from an "unknown" thread.
    # The following function can not use nim's stack trace and GC.
    {.push stack_trace:off.}
    proc timeoutThreadCallback(interval: uint32, data: pointer): uint32 =
        # This proc is run on a foreign thread!
        performOnMainThread(fireCallback, data)
        result = interval
    {.pop.}

proc newTimer*(interval: float, repeat: bool, callback: proc()): Timer =
    assert(not callback.isNil)
    result.new()
    result.callback = callback
    result.isPeriodic = repeat
    result.nextFireTime = epochTime() + interval
    result.interval = interval

    when defined(js):
        let t = result
        let cb = proc() =
            fireCallbackAux(t)
        if t.isPeriodic:
            result.timer = setInterval(cb, interval * 1000)
        else:
            result.timer = setTimeout(cb, interval * 1000)
    else:
        var sdlInitialized {.global.} = false
        if not sdlInitialized:
            sdl2.init(INIT_TIMER)
            sdlInitialized = true

        result.id = nextTimerId()
        allTimers[result.id] = result
        result.timer = addTimer(uint32(interval * 1000), timeoutThreadCallback, cast[pointer](result.id))

proc setTimeout*(interval: float, callback: proc()): Timer {.discardable.} =
    newTimer(interval, false, callback)

proc setInterval*(interval: float, callback: proc()): Timer {.discardable.} =
    newTimer(interval, true, callback)

proc pause*(t: Timer) = t.clear()

proc resume*(t: Timer) =
    if not t.isTimerValid:
        when defined(js):
            if t.isPeriodic:
                let cb = proc() =
                    t.fireCallbackAux()
                    let newcb = proc() =
                        t.fireCallbackAux()
                    t.timer = setInterval(newcb, t.interval * 1000)
                    t.isRescheduling = false

                t.timer = setTimeout(cb, t.nextFireTime * 1000)
                t.isRescheduling = true
            else:
                t.timer = setTimeout(t.callback, t.nextFireTime * 1000)
        else:
            t.id = nextTimerId()
            t.isRescheduling = true
            allTimers[t.id] = t
            t.timer = addTimer(uint32(t.nextFireTime * 1000), timeoutThreadCallback, cast[pointer](t.id))

        t.nextFireTime = t.nextFireTime + epochTime()
