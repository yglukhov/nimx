import tables
import variant

export variant

when defined(js):
    {.emit:"""
    var _nimx_observerIdCounter = 0;
    """.}

type NCObserverID = int
type NCCallback = proc(args: Variant)
type NCCallbackTable = TableRef[NCObserverID, NCCallback]
type NotificationCenter* = ref object of RootObj
    observers: Table[string, NCCallbackTable]

var gNotifCenter: NotificationCenter

proc sharedNotificationCenter*(): NotificationCenter=
    if gNotifCenter.isNil():
        gNotifCenter.new()
        gNotifCenter.observers = initTable[string, NCCallbackTable]()
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

proc removeObserver*(nc: NotificationCenter, observerId: ref | SomeOrdinal) =
    let obsId = getObserverID(observerId)
    var toRemoveKeys = newSeq[string]()

    for key, val in pairs(nc.observers):
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
