import times, system_logger, mini_profiler

when defined(js) or defined(emscripten):
    import jsbind
    type TimerID = ref object of JSObj
elif defined(macosx):
    type TimerID = pointer
elif defined(android):
    type TimerID = bool
else:
    import sdl2

type TimerState = enum
    tsInvalid
    tsRunning
    tsPaused

when defined(debugLeaks):
    var allTimers = newSeq[pointer]()

type Timer* = ref object
    callback: proc()
    origCallback: proc()
    when defined(android):
        mNextFireTime: float
    timer: TimerID
    interval: float
    isPeriodic: bool
    scheduleTime: float
    state: TimerState
    when (not defined(js) and not defined(emscripten)):
        ready: bool
    when defined(debugLeaks):
        instantiationStackTrace*: string

proc getNextFireTime*(t: Timer, curTime: float = epochTime()): float =
    # Private
    if t.interval == 0: return curTime
    let firedTimes = int((curTime - t.scheduleTime) / t.interval) + 1
    result = t.scheduleTime + float(firedTimes) * t.interval

proc timeLeftUntilNextFire(t: Timer): float =
    let curTime = epochTime()
    result = t.getNextFireTime(curTime) - curTime

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

elif defined(macosx):
    type
        CFTimeInterval = float64
        CFAbsoluteTime = CFTimeInterval
        CFIndex = cint
        CFOptionFlags = culong
        CFRunLoopTimerContext = object
            version: CFIndex
            info: pointer
            retain: pointer
            release: pointer
            copyDescription: pointer
        CFTypeRef = pointer
        CFRunLoopTimerRef = CFTypeRef
        CFAllocatorRef = CFTypeRef
        CFRunLoopRef = CFTypeRef
        CFStringRef = CFTypeRef
        CFRunLoopMode = CFStringRef

        CFRunLoopTimerCallBack = proc(cfTimer: CFRunLoopTimerRef, info: pointer) {.cdecl.}

    var kCFRunLoopCommonModes {.importc.}: CFRunLoopMode

    proc CFAbsoluteTimeGetCurrent(): CFAbsoluteTime {.importc.}
    proc CFRunLoopGetCurrent(): CFRunLoopRef {.importc.}
    proc CFRunLoopAddTimer(rl: CFRunLoopRef, timer: CFRunLoopTimerRef, mode: CFRunLoopMode) {.importc.}
    proc CFRunLoopTimerCreate(allocator: CFAllocatorRef, fireDate: CFAbsoluteTime, interval: CFTimeInterval, flags: CFOptionFlags, order: CFIndex, callout: CFRunLoopTimerCallBack, context: ptr CFRunLoopTimerContext): CFRunLoopTimerRef {.importc.}
    proc CFRunLoopTimerInvalidate(t: CFRunLoopTimerRef) {.importc.}
    proc CFRelease(o: CFTypeRef) {.importc.}
    proc CFRunLoopWakeUp(o: CFRunLoopRef) {.importc.}

    proc cftimerCallback(cfTimer: CFRunLoopTimerRef, t: pointer) {.cdecl.} =
        cast[Timer](t).callback()
        CFRunLoopGetCurrent().CFRunLoopWakeUp()

    proc schedule(t: Timer) =
        var interval = t.interval
        let nextFireTime = CFAbsoluteTimeGetCurrent() + interval
        if not t.isPeriodic: interval = 0
        var context: CFRunLoopTimerContext
        context.info = cast[pointer](t)
        let cfTimer = CFRunLoopTimerCreate(nil, nextFireTime, interval, 0, 0, cftimerCallback, addr context)
        CFRunLoopGetCurrent().CFRunLoopAddTimer(cfTimer, kCFRunLoopCommonModes)
        CFRelease(cfTimer)
        t.timer = cfTimer

    proc cancel(t: Timer) {.inline.} =
        CFRunLoopTimerInvalidate(t.timer)

elif defined(android):
    import heapqueue, locks, times, math
    import posix except Timer
    import android.ndk.alooper
    import sdl_perform_on_main_thread

    var timersLock: Lock
    var timersCond: Cond
    var timersThread: Thread[void]

    type Timeval {.importc: "struct timeval",
              header: "<sys/select.h>".} = object ## struct timeval
      tv_sec: int  ## Seconds.
      tv_usec: int ## Microseconds.

    proc posix_gettimeofday(tp: var Timeval, unused: pointer = nil) {.
        importc: "gettimeofday", header: "<sys/time.h>".}

    var nextFireTime: Timespec
    var armed = false

    proc `<`(a, b: Timer): bool =
        cmp(a.mNextFireTime, b.mNextFireTime) < 0

    var allTimers: HeapQueue[Timer]

    proc armTimer(fireTime: float) =
        let nf = splitDecimal(fireTime)
        timersLock.acquire()
        nextFireTime.tv_sec = Time(int(nf.intpart))
        nextFireTime.tv_nsec = int(nf.floatpart * 1000000000) # int((allTimers[0].mNextFireTime - curT) * 1000000000.float)
        armed = true
        timersCond.signal()
        timersLock.release()

    proc processTimers(unused: pointer) {.cdecl.} =
        if not seq[Timer](allTimers).isNil and allTimers.len > 0:
            let curTime = epochTime()
            while allTimers.len > 0:
                if curTime >= allTimers[0].mNextFireTime:
                    let t = allTimers.pop()
                    t.mNextFireTime = t.getNextFireTime(curTime)
                    allTimers.push(t)

                    # Call the callback after the timer is repositioned in the
                    # queue to prevent reentrancy errors.
                    t.callback()
                else:
                    break
            if allTimers.len > 0:
                armTimer(allTimers[0].mNextFireTime)

    proc wait*(cond: var Cond, lock: var Lock, timeout: ptr Timespec): cint {.nodecl, importc: "pthread_cond_timedwait".}

    proc timersRunner() {.cdecl.} =
        while true:
            var fireTime: Timespec
            timersLock.acquire()
            if armed:
                fireTime = nextFireTime
                armed = false
            else:
                var now: Timeval
                posix_gettimeofday(now)
                fireTime.tv_sec = Time(now.tv_sec + 60)
            let r = timersCond.wait(timersLock, addr fireTime)
            timersLock.release()
            if r == 110:
                performOnMainThread(processTimers, nil)

    proc timersRunnerAux() {.thread.} =
        let p = cast[proc(){.gcsafe, cdecl.}](timersRunner)
        p()

    proc initTimers() =
        initLock(timersLock)
        initCond(timersCond)
        allTimers = newHeapQueue[Timer]()
        createThread(timersThread, timersRunnerAux)

    proc schedule*(t: Timer) =
        t.timer = true
        t.mNextFireTime = t.getNextFireTime()
        if seq[Timer](allTimers).isNil:
            initTimers()
        allTimers.push(t)
        if allTimers[0] == t:
            armTimer(t.mNextFireTime)

    proc cancel*(t: Timer) =
        let i = seq[Timer](allTimers).find(t)
        assert(i != -1, "Internal nimx error: timer.cancel")
        allTimers.del(i)
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
        t.ready = true
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
            t.callback = nil
            t.origCallback = nil
            when not defined(js):
                GC_unref(t)

const profileTimers = not defined(js) and not defined(release)

when profileTimers or defined(debugLeaks):
    let totalTimers = sharedProfiler().newDataSource(int, "Timers")
    proc finalizeTimer(t: Timer) =
        dec totalTimers
        when defined(debugLeaks):
            let p = cast[pointer](t)
            let i = allTimers.find(p)
            assert(i != -1)
            allTimers.del(i)

proc newTimer*(interval: float, repeat: bool, callback: proc()): Timer =
    assert(not callback.isNil)
    when profileTimers:
        result.new(finalizeTimer)
        inc totalTimers
    else:
        result.new()

    when defined(debugLeaks):
        result.instantiationStackTrace = getStackTrace()
        allTimers.add(cast[pointer](result))

    when defined(js) or defined(emscripten):
        result.origCallback = proc() =
            handleJSExceptions:
                callback()
    else:
        result.origCallback = callback

    when defined(js):
        result.callback = result.origCallback
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
    result.schedule()

proc setTimeout*(interval: float, callback: proc()): Timer {.discardable.} =
    newTimer(interval, false, callback)

proc setInterval*(interval: float, callback: proc()): Timer {.discardable.} =
    newTimer(interval, true, callback)

proc pause*(t: Timer) =
    if t.state == tsRunning:
        var emptyId: TimerID
        if t.timer != emptyId:
            t.cancel()
            t.timer = emptyId
            t.scheduleTime = t.timeLeftUntilNextFire()
            t.state = tsPaused
            when not defined(js):
                GC_unref(t)

proc resume*(t: Timer) =
    if t.state == tsPaused:
        when not defined(js):
            GC_ref(t)
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
                t.cancel()
                t.schedule()
            t.schedule()
            t.isPeriodic = true
        else:
            t.schedule()
        t.interval = interval
        t.state = tsRunning

when defined(debugLeaks):
    iterator activeTimers*(): Timer =
        for t in allTimers:
            yield cast[Timer](t)
