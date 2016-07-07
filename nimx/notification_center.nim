import tables
import variant

export variant

when defined(js):
    {.emit:"""
    var observerIdCounter = 0;
    """.}

type NCObserverID = int
type NCCallback = proc(args: Variant)
type NCCallbackTable = Table[NCObserverID, NCCallback]
type NotificationCenter* = ref object of RootObj
    observers: Table[string, NCCallbackTable]

var gNotifCenter: NotificationCenter

proc sharedNotificationCenter*(): NotificationCenter=
    if gNotifCenter.isNil():
        gNotifCenter.new()
        gNotifCenter.observers = initTable[string, NCCallbackTable]()
    result = gNotifCenter

proc removeObserver*(nc: NotificationCenter, ev: string)=
    if nc.observers.hasKey(ev):
        nc.observers.del(ev)

proc getObserverID(rawId: ref | SomeOrdinal): int =
    var obsId : int
    when defined(js):
        when rawId is ref:
            {.emit: """
            if (`rawId`.__nimx_observer_id === undefined) {
                `rawId`["__nimx_observer_id"] = --observerIdCounter;
                console.log("newObserverId " , observerIdCounter)
            }
            `obsId` = `rawId`.__nimx_observer_id;
            """.}
        else:
            obsId = rawId.int
    else:
        obsId = cast[int](rawId)
    result = obsId

proc deleteWithLen(t: var NCCallbackTable, id: int): int=
    t.del(id)
    result = t.len

proc removeObserver*(nc: NotificationCenter, observerId: ref | SomeOrdinal) =
    let obsId = getObserverID(observerId)
    var toRemoveKeys = newSeq[string]()

    for key in nc.observers.keys:
        if nc.observers[key].deleteWithLen(obsId) == 0:
            toRemoveKeys.add(key)

    for key in toRemoveKeys:
        nc.observers.del(key)

proc addObserver*(nc: NotificationCenter, ev: string, observerId: ref | SomeOrdinal, cb: NCCallback) =
    let obsId = getObserverID(observerId)

    if not nc.observers.hasKey(ev):
        var obTable = initTable[int, NCCallback]()
        nc.observers.add(ev, obTable)

    nc.observers[ev].add(obsId, cb)

proc postNotification*(nc: NotificationCenter, ev: string, args: Variant) =
    if nc.observers.hasKey(ev):

        var observers = nc.observers[ev]

        for key, val in observers:
            val(args)

proc postNotification*(nc: NotificationCenter, ev: string)=
    nc.postNotification(ev, newVariant())


when isMainModule:

    proc tests(nc:NotificationCenter)=
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
                nc.removeObserver("test3")
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
        nc.removeObserver("test1")
        doAssert(nc.observers.len == 0)
        doAssert(step == 4)

    sharedNotificationCenter().tests()
