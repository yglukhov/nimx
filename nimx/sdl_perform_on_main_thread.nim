import sdl2

{.push stack_trace:off.}
proc performOnMainThread*(fun: proc(data: pointer) {.cdecl.}, data: pointer): int {.discardable.} =
    var evt: UserEventObj
    evt.kind = UserEvent5
    evt.data1 = fun
    evt.data2 = data
    result = pushEvent(cast[ptr Event](addr evt))
{.pop.}
