
when defined(js):
    type Timer* {.importc.} = ref object
else:
    import sdl2, sdl_perform_on_main_thread
    type Timer* = ref object
        timer: TimerID
        callback: proc()
        isPeriodic: bool


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
            if t.timer != 0:
                discard removeTimer(t.timer)
                GC_unref(t)
                t.timer = 0

when not defined(js):
    proc timeoutCallback(data: pointer) {.cdecl.} =
        let t = cast[Timer](data)
        # Referring to t may be unsafe here
        if t.timer != 0:
            t.callback()
            if not t.isPeriodic:
                discard removeTimer(t.timer)
                t.timer = 0
                GC_unref(t)

    # Nim is hostile when it's callbacks are called from an "unknown" thread.
    # The following function can not use nim's stack trace and GC.
    {.push stack_trace:off.}
    proc timeoutThreadCallback(interval: uint32, data: pointer): uint32 {.cdecl, thread.} =
        performOnMainThread(timeoutCallback, data)
        result = interval
    {.pop.}

proc newTimer*(interval: float, repeat: bool, callback: proc()): Timer =
    when defined(js):
        asm """
        `result` = setTimeout(`callback`, `interval` * 1000);
        `result`.__nimx_periodic = `repeat`;
        """
    else:
        var sdlInitialized {.global.} = false
        if not sdlInitialized:
            sdl2.init(INIT_TIMER)
            sdlInitialized = true

        result.new()
        result.callback = callback
        result.timer = addTimer(uint32(interval * 1000), timeoutThreadCallback, cast[pointer](result))
        result.isPeriodic = repeat
        GC_ref(result)

proc setTimeout*(interval: float, callback: proc()): Timer {.discardable.} =
    newTimer(interval, false, callback)

proc setInterval*(interval: float, callback: proc()): Timer {.discardable.} =
    newTimer(interval, true, callback)
