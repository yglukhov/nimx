import times, system_logger

when defined(js) or defined(emscripten):
    import jsbind
    type TimerID = ref object of JSObj
elif (defined(macosx) or defined(ios)) and defined(nimxAvoidSDL):
    type TimerID = pointer
else:
    import sdl2

type TimerState = enum
    tsInvalid
    tsRunning
    tsPaused

type Timer* = ref object
    callback: proc()
    origCallback: proc()
    timer: TimerID
    interval: float
    isPeriodic: bool
    scheduleTime: float
    state: TimerState
    ready: bool

when defined(js) or defined(emscripten):
    proc setInterval(p: proc(), timeout: float): TimerID {.jsImportg.}
    proc setTimeout(p: proc(), timeout: float): TimerID {.jsImportg.}
    proc clearInterval(t: TimerID) {.jsImportg.}
    proc clearTimeout(t: TimerID) {.jsImportg.}

    proc schedule(t: Timer) =
        if t.isPeriodic:
            t.timer = setInterval(t.callback, t.interval * 1000)
        else:
            t.timer = setTimeout(t.callback, t.interval * 1000)

    template cancel(t: Timer) =
        if t.isPeriodic:
            clearInterval(t.timer)
        else:
            clearTimeout(t.timer)

elif (defined(macosx) or defined(ios)) and defined(nimxAvoidSDL):
    {.emit: """
    #include <CoreFoundation/CoreFoundation.h>
    """.}
    proc cftimerCallback(cfTimer: pointer, t: Timer) {.cdecl.} =
        if not t.isPeriodic:
            t.timer = 0
        t.callback()

    proc schedule(t: Timer) =
        var interval = t.interval
        var repeats = t.isPeriodic
        var cfTimer: TimerID
        {.emit: """
        CFAbsoluteTime nextFireTime = CFAbsoluteTimeGetCurrent() + `interval`;
        if (!`repeats`) `interval` = 0;
        CFRunLoopTimerContext context;
        context.version = 0;
        context.info = `t`;
        context.retain = NULL;
        context.release = NULL;
        context.copyDescription = NULL;
        CFRunLoopTimerRef tr = CFRunLoopTimerCreate(NULL, nextFireTime, `interval`, 0, 0, `cftimerCallback`, &context);
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), tr, kCFRunLoopCommonModes);
        `cfTimer` = tr;
        CFRelease(tr);
        """.}
        t.timer = cfTimer

    template cancel(t: Timer) =
        let cfTimer = t.timer
        {.emit: """
        CFRunLoopTimerInvalidate(`cfTimer`);
        """.}
else:
    import sdl_perform_on_main_thread

    proc fireCallback(timer: pointer) {.cdecl.} =
        var t = cast[Timer](timer)
        if t.state == tsRunning:
            t.callback()
            t.ready = true

    # Nim is hostile when it's callbacks are called from an "unknown" thread.
    # The following function can not use nim's stack trace and GC.

    {.push stackTrace: off.}
    proc timeoutThreadCallback(interval: uint32, timer: pointer): uint32 {.cdecl.} =
        # This proc is run on a foreign thread!
        let t = cast[ptr type(cast[Timer](timer)[])](timer)

        if t.ready:
            t.ready = false
            performOnMainThread(fireCallback, timer)

        if t.isPeriodic:
            result = interval
        else:
            result = 0
    {.pop.}

    proc schedule(t: Timer) =
        t.timer = addTimer(uint32(t.interval * 1000), timeoutThreadCallback, cast[pointer](t))

    template cancel(t: Timer) =
        discard removeTimer(t.timer)
        t.ready = false

proc clear*(t: Timer) =
    if not t.isNil:
        var emptyId: TimerID
        if t.timer != emptyId:
            t.cancel()
            t.timer = emptyId
            t.state = tsInvalid
            when not defined(js):
                GC_unref(t)

proc newTimer*(interval: float, repeat: bool, callback: proc()): Timer =
    assert(not callback.isNil)
    result.new()
    result.origCallback = callback
    when defined(js):
        result.callback = callback
    else:
        let t = result
        GC_ref(t)
        if repeat:
            t.callback = callback
        else:
            t.callback = proc() =
                t.origCallback()
                t.clear()

    result.isPeriodic = repeat
    result.interval = interval
    result.scheduleTime = epochTime()
    result.state = tsRunning
    result.ready = true
    result.schedule()

proc setTimeout*(interval: float, callback: proc()): Timer {.discardable.} =
    newTimer(interval, false, callback)

proc setInterval*(interval: float, callback: proc()): Timer {.discardable.} =
    newTimer(interval, true, callback)

proc timeLeftUntilNextFire(t: Timer): float =
    let curTime = epochTime()
    let firedTimes = int((curTime - t.scheduleTime) / t.interval) + 1
    result = t.scheduleTime + float(firedTimes) * t.interval
    result = result - curTime

proc pause*(t: Timer) =
    if t.state != tsPaused:
        t.clear()
        t.scheduleTime = t.timeLeftUntilNextFire()
        t.state = tsPaused

proc resume*(t: Timer) =
    if t.state == tsPaused:
        # At this point t.scheduleTime is equal to number of seconds remaining
        # until next fire.
        let interval = t.interval
        t.interval = t.scheduleTime
        t.scheduleTime = epochTime() - (interval - t.scheduleTime)
        if t.isPeriodic:
            t.isPeriodic = false
            t.callback = proc() =
                t.callback = t.origCallback
                t.origCallback()
                t.schedule()
            t.schedule()
            t.isPeriodic = true
        else:
            t.schedule()
        t.interval = interval
        t.state = tsRunning
