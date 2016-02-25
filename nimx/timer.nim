
when defined(js):
    type Timer* {.importc.} = ref object
else:
    import sdl2, sdl_perform_on_main_thread
    type Timer* = ref object
        timer: TimerID
        callback: proc()
        isPeriodic: bool
        cancelled: bool

proc clear*(t: Timer) =
    if not t.isNil:
        when defined(js):
            asm """
            if (`t`.__nimx_periodic) {
                clearInterval(`t`);
            }
            else {
                clearTimeout(`t`);
            }
            """
        else:
            t.cancelled = true

when not defined(js):
    proc finalizeCallback(data: pointer) {.cdecl.} =
        let t = cast[Timer](data)
        GC_unref(t)

    proc fireAndFinalizeCallback(data: pointer) {.cdecl.} =
        let t = cast[Timer](data)
        if not t.cancelled:
            t.callback()
        GC_unref(t)

    proc fireCallback(data: pointer) {.cdecl, gcsafe.} =
        let t = cast[Timer](data)
        if not t.cancelled:
            t.callback()

    # Nim is hostile when it's callbacks are called from an "unknown" thread.
    # The following function can not use nim's stack trace and GC.
    {.push stack_trace:off.}
    proc timeoutThreadCallback(interval: uint32, data: pointer): uint32 {.cdecl, thread.} =
        let t = cast[Timer](data)
        if t.cancelled:
            performOnMainThread(finalizeCallback, data)
        elif t.isPeriodic:
            performOnMainThread(fireCallback, data)
            result = interval
        else:
            performOnMainThread(fireAndFinalizeCallback, data)
    {.pop.}

proc newTimer*(interval: float, repeat: bool, callback: proc()): Timer =
    doAssert(not callback.isNil)
    when defined(js):
        asm """
        `result` = `repeat` ? setInterval(`callback`, `interval` * 1000) : setTimeout(`callback`, `interval` * 1000);
        `result`.__nimx_periodic = `repeat`;
        """
    else:
        var sdlInitialized {.global.} = false
        if not sdlInitialized:
            sdl2.init(INIT_TIMER)
            sdlInitialized = true

        result.new()
        result.callback = callback
        result.isPeriodic = repeat
        result.timer = addTimer(uint32(interval * 1000), timeoutThreadCallback, cast[pointer](result))
        GC_ref(result)

proc setTimeout*(interval: float, callback: proc()): Timer {.discardable.} =
    newTimer(interval, false, callback)

proc setInterval*(interval: float, callback: proc()): Timer {.discardable.} =
    newTimer(interval, true, callback)
