import tables

type Profiler* = ref object
    values: Table[string, string]
    enabled*: bool

var gProfiler : Profiler

proc newProfiler*(): Profiler =
    result.new()
    result.values = initTable[string, string]()
    when not defined(release):
        result.enabled = true

proc sharedProfiler*(): Profiler =
    if gProfiler.isNil:
        gProfiler = newProfiler()
    result = gProfiler

template setValueForKey*(p: Profiler, key, value: string) =
    p.values[key] = value

template `[]=`*(p: Profiler, key: string, value: typed) =
    p.setValueForKey(key, $value)

iterator pairs*(p: Profiler): tuple[key, value: string] =
    for p in pairs(p.values): yield p

template len*(p: Profiler): int = p.values.len
