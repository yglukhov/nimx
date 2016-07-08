import times

const jsCompatibleAPI = defined(js) or defined(emscripten)

when defined(js):
    type TimerID {.importc.} = ref object
    const nilTimer : TimerID = nil

    proc setInterval(p: proc(), timeout: float): TimerID {.importc.}
    proc setTimeout(p: proc(), timeout: float): TimerID {.importc.}
    proc clearInterval(t: TimerID) {.importc.}
    proc clearTimeout(t: TimerID) {.importc.}
elif defined(emscripten):
    import emscripten
    type TimerID = pointer
    const nilTimer : TimerID = nil

    type Context = ref object
        handler: proc()

    proc initTimers() =
        EM_ASM """
        window.__nimx_timers = {};
        """

    initTimers()

    proc timerCallback(c: pointer) {.EMSCRIPTEN_KEEPALIVE.} =
        let ctx = cast[Context](c)
        ctx.handler()

    proc deleteTimerContext(c: pointer) {.EMSCRIPTEN_KEEPALIVE.} =
        let ctx = cast[Context](c)
        GC_unref(ctx)

    proc setInterval(p: proc(), timeout: float): TimerID =
        let ctx = Context.new()
        ctx.handler = p
        GC_ref(ctx)
        result = cast[pointer](ctx)
        discard EM_ASM_INT("""
        var timer = setInterval(function() {
            _timerCallback($1);
        }, $0);
        window.__nimx_timers[$1] = timer;
        return 0;
        """, cfloat(timeout), cast[pointer](ctx))

    proc setTimeout(p: proc(), timeout: float): TimerID =
        let ctx = Context.new()
        ctx.handler = p
        GC_ref(ctx)
        result = cast[pointer](ctx)
        discard EM_ASM_INT("""
        var timer = setTimeout(function() {
            _timerCallback($1);
            var t = window.__nimx_timers[$1];
            if (t !== undefined) {
                _deleteTimerContext($1);
                delete window.__nimx_timers[$1];
            }
        }, $0);
        window.__nimx_timers[$1] = timer;
        return 0;
        """, cfloat(timeout), cast[pointer](ctx))

    proc clearInterval(t: TimerID) =
        discard EM_ASM_INT("""
        var t = window.__nimx_timers[$0];
        if (t !== undefined) {
            clearInterval(t);
            delete window.__nimx_timers[$0];
            _deleteTimerContext($0);
        }
        """, t)

    proc clearTimeout(t: TimerID) =
        discard EM_ASM_INT("""
        var t = window.__nimx_timers[$0];
        if (t !== undefined) {
            clearTimeout(t);
            delete window.__nimx_timers[$0];
            _deleteTimerContext($0);
        }
        """, t)

else:
    import sdl2, sdl_perform_on_main_thread, tables

type UserData = ref object
    id: int
    isHandled: bool

type Timer* = ref object
    callback: proc()
    timer: TimerID
    nextFireTime: float
    interval: float
    isPeriodic: bool
    isRescheduling: bool
    when not defined(js):
        id: int
        userData: UserData

template fireCallbackAux(t: Timer) =
    t.callback()
    if t.isPeriodic:
        t.nextFireTime = epochTime() + t.interval
        if t.isRescheduling:
            discard

when not jsCompatibleAPI:
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

    proc nextTimerId(): int =
        var idCounter {.global.} = 0
        inc idCounter
        result = idCounter

    proc timeoutThreadCallback(interval: uint32, data: pointer): uint32 {.cdecl.}

    proc fireCallback(data: pointer) {.cdecl.} =
        var ud = cast[UserData](data)
        let t = allTimers.getOrDefault(ud.id)
        if not t.isNil:
            t.fireCallbackAux()

            if not t.isPeriodic:
                t.deleteTimerFromSDL()
            elif t.isRescheduling:
                t.deleteTimerFromSDL()
                t.id = nextTimerId()
                t.isRescheduling = false
                allTimers[t.id] = t
                t.timer = addTimer(uint32(t.interval * 1000), timeoutThreadCallback, cast[pointer](t.userData))

            t.userData.isHandled = false

    # Nim is hostile when it's callbacks are called from an "unknown" thread.
    # The following function can not use nim's stack trace and GC.
    {.push stack_trace:off.}
    proc timeoutThreadCallback(interval: uint32, data: pointer): uint32 =
        # This proc is run on a foreign thread!

        var ud = cast[UserData](data)
        if not ud.isNil and not ud.isHandled:

            var res = performOnMainThread(fireCallback, data)

            if  res == 1:   # success
                ud.isHandled = true
            elif res == 0:  # event filtered
                ud.isHandled = false
            else:           # -1 error or event stack full
                ud.isHandled = false

        result = interval
    {.pop.}

template isTimerValid(t: Timer): bool =
    when jsCompatibleAPI:
        not t.timer.isNil
    else:
        t.timer != 0

proc clear*(t: Timer) =
    if not t.isNil:
        if t.isTimerValid:
            when jsCompatibleAPI:
                if t.isPeriodic and not t.isRescheduling:
                    clearInterval(t.timer)
                else:
                    clearTimeout(t.timer)
                t.timer = nilTimer
            else:
                t.deleteTimerFromSDL()
            t.nextFireTime = t.nextFireTime - epochTime()

proc newTimer*(interval: float, repeat: bool, callback: proc()): Timer =
    assert(not callback.isNil)
    result.new()
    result.callback = callback
    result.isPeriodic = repeat
    result.nextFireTime = epochTime() + interval
    result.interval = interval

    when jsCompatibleAPI:
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
        result.userData = new(UserData)
        result.userData.id = result.id
        result.userData.isHandled = false
        result.timer = addTimer(uint32(interval * 1000), timeoutThreadCallback, cast[pointer](result.userData))

proc setTimeout*(interval: float, callback: proc()): Timer {.discardable.} =
    newTimer(interval, false, callback)

proc setInterval*(interval: float, callback: proc()): Timer {.discardable.} =
    newTimer(interval, true, callback)

proc pause*(t: Timer) = t.clear()

proc resume*(t: Timer) =
    if not t.isTimerValid:
        when jsCompatibleAPI:
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
            t.timer = addTimer(uint32(t.nextFireTime * 1000), timeoutThreadCallback, cast[pointer](t.userData))

        t.nextFireTime = t.nextFireTime + epochTime()
