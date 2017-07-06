import tables, sequtils, macros

import variant # for legacy api
export variant

type
    NotificationCenter* = ref object
        notificationsMap: Table[int, ObserversMap]
        observers: Table[string, NCCallbackTable] # legacy

    Notification[T] = distinct int

    ObserverId = int
    ObserversMap = TableRef[ObserverId, proc()]

    NCCallback = proc(args: Variant) # legacy
    NCCallbackTable = TableRef[ObserverId, NCCallback] # legacy


var idCounter {.compileTime.} = 0

proc nextNotifId(): int {.compileTime.} =
    inc idCounter
    idCounter

template notification*(T: typed): untyped = Notification[T](nextNotifId())

proc newNotificationCenter*(): NotificationCenter =
    result.new()
    result.notificationsMap = initTable[int, ObserversMap]()
    result.observers = initTable[string, NCCallbackTable]() # legacy

var gNotifCenter: NotificationCenter

proc sharedNotificationCenter*(): NotificationCenter =
    if gNotifCenter.isNil():
        gNotifCenter = newNotificationCenter()
    result = gNotifCenter

proc addObserverAux(nc: NotificationCenter, notificationId: int, observer: ObserverId, action: proc()) =
    var obsMap = nc.notificationsMap.getOrDefault(notificationId)
    if obsMap.isNil:
        obsMap = newTable[ObserverId, proc()]()
        nc.notificationsMap[notificationId] = obsMap
    obsMap[observer] = action

proc removeObserverAux(nc: NotificationCenter, notificationId: int, observer: ObserverId) =
    var obsMap = nc.notificationsMap.getOrDefault(notificationId)
    if not obsMap.isNil:
        obsMap.del(observer)
        if obsMap.len == 0:
            nc.notificationsMap.del(notificationId)

proc removeObserverInOldDeprecatedWay(nc: NotificationCenter, obsId: ObserverId)

proc removeObserverAux(nc: NotificationCenter, observer: ObserverId) =
    var removedKeys: seq[int]
    for k, v in nc.notificationsMap:
        v.del(observer)
        if v.len == 0:
            if removedKeys.isNil: removedKeys = @[]
            removedKeys.add(k)

    for k in removedKeys: nc.notificationsMap.del(k)

    nc.removeObserverInOldDeprecatedWay(observer)

when defined(js):
    {.emit:"""
    var _nimx_observerIdCounter = 0;
    """.}

    proc getObserverId(rawId: RootRef): ObserverId =
        {.emit: """
        if (`rawId`.__nimx_observer_id === undefined) {
            `rawId`.__nimx_observer_id = --_nimx_observerIdCounter;
        }
        `result` = `rawId`.__nimx_observer_id;
        """.}
    template getObserverID(rawId: ref): ObserverId = getObserverId(cast[RootRef](rawId))
    template getObserverID(rawId: SomeOrdinal): ObserverId = int(rawId)

    template castProc[TTo, TFrom](p: TFrom): TTo = cast[TTo](p)

else:
    template getObserverID(rawId: ref | SomeOrdinal): ObserverId = cast[int](rawId)

    proc castProc[TTo, TFrom](p: TFrom): TTo {.inline.} =
        # This is needed because of nim bug #5785. Otherwise regular cast could be used
        {.emit: """
        `result`->ClP_0 = `p`.ClP_0;
        `result`->ClE_0 = `p`.ClE_0;
        """.}

{.push stackTrace: off, inline.}

proc addObserver*[T: proc](nc: NotificationCenter, name: Notification[T], observerId: ref | SomeOrdinal, action: T) =
    nc.addObserverAux(int(name), getObserverID(observerId), castProc[proc(), T](action))

proc addObserver*[T](nc: NotificationCenter, name: Notification[T], action: T) =
    nc.addObserver(name, 0, action)

{.pop.}

template removeObserver*(nc: NotificationCenter, name: Notification, observerId: ref | SomeOrdinal) =
    nc.removeObserverAux(int(name), getObserverID(observerId))

template removeObserver*(nc: NotificationCenter, observerId: ref | SomeOrdinal) =
    nc.removeObserverAux(getObserverID(observerId))

macro appendTupleToCall(c: untyped, e: typed): untyped =
    let typ = getTypeInst(e)
    result = c
    if typ.kind == nnkTupleTy:
        let ln = typ.len
        for i in 0 ..< ln:
            result.add(newNimNode(nnkBracketExpr).add(e, newLit(i)))
    else:
        result.add(e)

proc newTupleAux(args: NimNode): NimNode =
    result = newNimNode(nnkPar)
    for c in args: result.add(c)

macro newTuple(args: varargs[typed]): untyped =
    newTupleAux(args)

macro newTuple(args: untyped): untyped =
    newTupleAux(args)

# All this dancing with pointers and casts may be prettier at the cost
# of additional closure allocation on every postNotification. We prefer to
# avoid this allocation, so... yeah...
proc dispatchNotification(nc: NotificationCenter, notificationId: int, ctx: pointer, dispatch: proc(prc: proc(), ctx: pointer) {.nimcall.}) =
    let obsMap = nc.notificationsMap.getOrDefault(notificationId)
    if not obsMap.isNil:
        # dispatch is reentrant!
        let vals = toSeq(values(obsMap))
        for p in vals: dispatch(p, ctx)

proc dispatchForwarder[TProc, TTuple](prc: proc(), ctx: pointer) =
    let p = castProc[TProc, proc()](prc)
    when defined(js):
        var localT: TTuple
        {.emit: [localT, "=", ctx, ";"].}
        appendTupleToCall(p(), localT)
    else:
        appendTupleToCall(p(), cast[ptr TTuple](ctx)[])

template postNotification*[T: proc](nc: NotificationCenter, name: Notification[T], args: varargs[typed]) =
    var t = newTuple(args)
    var pt {.noInit.}: pointer
    when defined(js):
        {.emit: [pt, "=", t, ";"].}
    else:
        pt = addr t

    dispatchNotification(nc, int(name), pt, dispatchForwarder[T, type(t)])


when isMainModule:
    const TEST_NOTIFICATION_INT = notification(proc(param: int))
    const TEST_NOTIFICATION_SEQ = notification(proc(param: seq[int]))
    const TEST_NOTIFICATION_OPENARRAY = notification(proc(param: openarray[int]))
    const TEST_NOTIFICATION_TWOARGS = notification(proc(a: float, b: int))
    const TEST_NOTIFICATION_NO_PARAMS = notification(proc())

    let nc = newNotificationCenter()

    var WINDOW_FOCUS_received = 0

    nc.addObserver(TEST_NOTIFICATION_INT) do(arg: int):
        WINDOW_FOCUS_received += arg

    nc.postNotification(TEST_NOTIFICATION_INT, 5)

    doAssert(WINDOW_FOCUS_received == 5)

    var TEST_NOTIFICATION_SEQ_received = 0

    nc.addObserver(TEST_NOTIFICATION_SEQ) do(params: seq[int]):
        TEST_NOTIFICATION_SEQ_received += params.len

    nc.postNotification(TEST_NOTIFICATION_SEQ, @[5, 10])

    doAssert(TEST_NOTIFICATION_SEQ_received == 2)

    var TEST_NOTIFICATION_OPENARRAY_received = 0

    nc.addObserver(TEST_NOTIFICATION_OPENARRAY, 1) do(params: openarray[int]):
        doAssert(params.len == 3)
        TEST_NOTIFICATION_OPENARRAY_received += params.len

    nc.addObserver(TEST_NOTIFICATION_OPENARRAY, 2) do(params: openarray[int]):
        TEST_NOTIFICATION_OPENARRAY_received += params.len

    var getArr_called = 0

    proc getArr(): seq[int] =
        inc getArr_called
        @[1, 2, 3]

    var TEST_NOTIFICATION_TWOARGS_received = 0
    nc.addObserver(TEST_NOTIFICATION_TWOARGS, 3) do(a: float, b: int):
        doAssert(a == 123)
        doAssert(b == 456)
        inc TEST_NOTIFICATION_TWOARGS_received

    nc.postNotification(TEST_NOTIFICATION_OPENARRAY, getArr())
    nc.postNotification(TEST_NOTIFICATION_TWOARGS, 123.0, 456)


    doAssert(getArr_called == 1)
    doAssert(WINDOW_FOCUS_received == 5)
    doAssert(TEST_NOTIFICATION_OPENARRAY_received == 6)
    doAssert(TEST_NOTIFICATION_TWOARGS_received == 1)

    var TEST_NOTIFICATION_NO_PARAMS_received = 0
    nc.addObserver(TEST_NOTIFICATION_NO_PARAMS, 4) do():
        inc TEST_NOTIFICATION_NO_PARAMS_received

    nc.postNotification(TEST_NOTIFICATION_NO_PARAMS)
    doAssert(TEST_NOTIFICATION_NO_PARAMS_received == 1)
    nc.removeObserver(4)
    nc.postNotification(TEST_NOTIFICATION_NO_PARAMS)
    doAssert(TEST_NOTIFICATION_NO_PARAMS_received == 1)



################################################################################
# The rest is legacy api which will be removed soon
################################################################################
proc removeObserver*(nc: NotificationCenter, ev: string, observerId: ref | SomeOrdinal) =
    let obsId = getObserverID(observerId)
    let o = nc.observers.getOrDefault(ev)
    if not o.isNil:
        o.del(obsId)
        if o.len == 0:
            nc.observers.del(ev)

# use removeObserver*(nc: NotificationCenter, ev: string, observerId: ref | SomeOrdinal)
proc removeObserver*(nc: NotificationCenter,ev: string) {.deprecated.} =
    nc.observers.del(ev)

proc removeObserverInOldDeprecatedWay(nc: NotificationCenter, obsId: ObserverId) =
    var toRemoveKeys = newSeq[string]()

    for key, val in pairs(nc.observers):
        while not val.getOrDefault(obsId).isNil:
            val.del(obsId)
        if val.len == 0:
            toRemoveKeys.add(key)

    for key in toRemoveKeys:
        nc.observers.del(key)

proc addObserver*(nc: NotificationCenter, ev: string, observerId: ref | SomeOrdinal, cb: NCCallback) =
    let obsId = getObserverID(observerId)
    var o = nc.observers.getOrDefault(ev)
    if o.isNil:
        o = newTable[int, NCCallback]()
        nc.observers[ev] = o
    o.add(obsId, cb)

proc postNotification*(nc: NotificationCenter, ev: string, args: Variant) =
    let o = nc.observers.getOrDefault(ev)
    if not o.isNil:
        for v in o.values:
            v(args)

proc hasObserver*(nc: NotificationCenter, ev: string): bool =
    let o = nc.observers.getOrDefault(ev)
    result = not o.isNil

proc postNotification*(nc: NotificationCenter, ev: string)=
    nc.postNotification(ev, newVariant())


when isMainModule:
    proc tests*(nc:NotificationCenter)=
        const test1arg = "some string"
        var step = 0

        nc.addObserver("test1", 15, proc(args: Variant)=
            doAssert( args.get(string) == test1arg)
            inc step
        )
        nc.addObserver("test1", 19, proc(args: Variant)=
            doAssert( args.get(string) == test1arg)
            inc step
        )
        nc.addObserver("test1", 17, proc(args: Variant)=
            doAssert( args.get(string) == test1arg)
            inc step

            nc.addObserver("test3", nc, proc(args: Variant)=
                nc.removeObserver("test3", nc)
                inc step
            )
        )
        nc.addObserver("test1", 150, proc(args: Variant)=
            doAssert(false)
        )
        nc.addObserver("ignored", 150, proc(args: Variant)=
            doAssert(false)
        )
        nc.addObserver("test2", nc, proc(args: Variant)=
            doAssert(false)
        )

        nc.removeObserver(150)
        nc.postNotification("test1", newVariant(test1arg))
        nc.postNotification("test3")
        nc.removeObserver(nc)
        nc.postNotification("test2", newVariant(test1arg))

        doAssert(nc.observers.len == 1)
        nc.removeObserver("test1", 15)
        nc.removeObserver("test1", 19)
        nc.removeObserver("test1", 13)
        nc.removeObserver("test1", 17)
        doAssert(nc.observers.len == 0)
        doAssert(step == 4)

    sharedNotificationCenter().tests()
