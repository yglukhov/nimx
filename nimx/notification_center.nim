import tables, macros, logging
import variant

export variant

when defined(js):
    {.emit:"""
    var _nimx_observerIdCounter = 0;
    """.}

type
    NotificationCenter* = ref object of RootObj
        observers: Table[string, NCCallbackTable]

    NCObserverID = int
    NCCallback = Variant
    NCCallbackTable = TableRef[NCObserverID, NCCallback]

var gNotifCenter: NotificationCenter

proc newNotificationCenter*(): NotificationCenter =
    result.new()
    result.observers = initTable[string, NCCallbackTable]()

proc sharedNotificationCenter*(): NotificationCenter =
    if gNotifCenter.isNil:
        gNotifCenter = newNotificationCenter()
    result = gNotifCenter

proc getObserverID(rawId: ref | SomeOrdinal): int =
    when defined(js):
        when rawId is ref:
            {.emit: """
            if (`rawId`.__nimx_observer_id === undefined) {
                `rawId`["__nimx_observer_id"] = --_nimx_observerIdCounter;
            }
            `result` = `rawId`.__nimx_observer_id;
            """.}
        else:
            result = rawId.int
    else:
        result = cast[int](rawId)

proc removeObserverAux(nc: NotificationCenter, ev: string, obsId: NCObserverID) =
    let o = nc.observers.getOrDefault(ev)
    if not o.isNil:
        o.del(obsId)
        if o.len == 0:
            nc.observers.del(ev)

proc removeObserver*(nc: NotificationCenter, ev: string, observerId: ref | SomeOrdinal) =
    nc.removeObserverAux(ev, getObserverID(observerId))

# use removeObserver*(nc: NotificationCenter, ev: string, observerId: ref | SomeOrdinal)
proc removeObserver*(nc: NotificationCenter,ev: string) {.deprecated.} =
    nc.observers.del(ev)

proc removeObserver*(nc: NotificationCenter, observerId: ref | SomeOrdinal) =
    let obsId = getObserverID(observerId)
    var toRemoveKeys = newSeq[string]()

    for key, val in pairs(nc.observers):
        val.del(obsId)
        if val.len == 0:
            toRemoveKeys.add(key)

    for key in toRemoveKeys:
        nc.observers.del(key)

proc addObserverAux(nc: NotificationCenter, ev: string, observerId: NCObserverID, cb: Variant) =
    var o = nc.observers.getOrDefault(ev)
    if o.isNil:
        o = newTable[int, NCCallback]()
        nc.observers[ev] = o
    o.add(observerId, cb)

proc addObserver*(nc: NotificationCenter, ev: string, observerId: ref | SomeOrdinal, cb: proc) =
    nc.addObserverAux(ev, getObserverID(observerId), newVariant(cb))

macro procTypeWithArgs(args: untyped): untyped =
    result = newNimNode(nnkProcTy)
    let params = newNimNode(nnkFormalParams).add(newEmptyNode())
    var i = 0
    for a in args:
        params.add(newNimNode(nnkIdentDefs).add(newIdentNode("a" & $i), getTypeInst(a), newEmptyNode()))
        inc i
    result.add(params)
    result.add(newEmptyNode())

macro appendVarargToCall(c: untyped, e: untyped): untyped =
    result = c
    for a in e.children:
        result.add(a)

macro firstArg(args: untyped): untyped =
    for a in args: return a

macro varargsLen(args: untyped): int =
    var r = 0
    for a in args:
        inc r
    result = newLit(r)

template postNotification*(nc: NotificationCenter, ev: string, args: varargs[typed]) =
    let o = nc.observers.getOrDefault(ev)
    type CBType = procTypeWithArgs(args)
    type CompatCBType = proc(v: Variant)
    if not o.isNil:
        for v in o.values:
            if v.ofType(CBType):
                appendVarargToCall(v.getProc(CBType)(), args)
            elif v.ofType(CompatCBType):
                when varargsLen(args) == 0:
                    v.getProc(CompatCBType)(newVariant())
                elif type(firstArg(args)) is Variant:
                    v.getProc(CompatCBType)(firstArg(args))
                else:
                    v.getProc(CompatCBType)(newVariant(firstArg(args)))
            else:
                warn "Wrong callback type for notification: ", ev

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

        # Fancy new api
        nc.addObserver("test1", 18) do(a, b: int):
            inc step
        nc.postNotification("test1", 5, 6)
        nc.postNotification("test1", 5, 6, 7)
        nc.removeObserver("test1", 18)
        doAssert(nc.observers.len == 0)
        doAssert(step == 5)

    sharedNotificationCenter().tests()
