
when defined(js):
    type Timer = distinct int
else:
    import sdl2
    type Timer* = ref object
        timer: TimerID
        callback: proc()
        isPeriodic: bool


proc clear*(t: Timer) =
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
        t.callback()
        if not t.isPeriodic:
            # The timer was already removed in the thread
            GC_unref(t)

    proc timeoutThreadCallback(interval: uint32, data: pointer): uint32 {.cdecl.} =
        var evt: UserEventObj
        evt.kind = UserEvent5
        evt.data1 = timeoutCallback
        evt.data2 = data
        # TODO: Refering to t may be unsafe here!
        let t = cast[Timer](data)
        if t.isPeriodic:
            result = interval
        else:
            discard removeTimer(t.timer)
            t.timer = 0
        discard pushEvent(cast[ptr Event](addr evt))

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

