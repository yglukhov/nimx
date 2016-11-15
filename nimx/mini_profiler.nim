import tables

type
    ProfilerDataSourceBase {.pure.} = ref object {.inheritable.}
        stringifiedValue: string
        updateImpl: proc(ds: ProfilerDataSourceBase) {.nimcall.}
        isDirty: bool

    ProfilerDataSource*[T] = ref object of ProfilerDataSourceBase
        mValue: T

    Profiler* = ref object
        values: Table[string, ProfilerDataSourceBase]
        enabled*: bool

proc updateDataSource[T](ds: ProfilerDataSourceBase) {.nimcall.} =
    let ds = cast[ProfilerDataSource[T]](ds)
    ds.stringifiedValue = $ds.mValue
    shallow(ds.stringifiedValue)
    ds.isDirty = false

var gProfiler : Profiler

proc newProfiler*(): Profiler =
    result.new()
    result.values = initTable[string, ProfilerDataSourceBase]()
    when defined(miniProfiler):
        result.enabled = true

proc newDataSource*(p: Profiler, typ: typedesc, name: string): ProfilerDataSource[typ] =
    result.new()
    result.stringifiedValue = ""
    type TT = typ
    result.updateImpl = updateDataSource[TT]
    p.values[name] = result

proc sharedProfiler*(): Profiler =
    if gProfiler.isNil:
        gProfiler = newProfiler()
    result = gProfiler

proc setValueForKey*(p: Profiler, key, value: string) =
    var ds = p.values.getOrDefault(key)
    if ds.isNil:
        ds.new()
        p.values[key] = ds
    ds.stringifiedValue = value

template `[]=`*(p: Profiler, key: string, value: typed) =
    p.setValueForKey(key, $value)

proc valueForKey*(p: Profiler, key: string): string =
    let v = p.values.getOrDefault(key)
    if not v.isNil:
        if v.isDirty: v.updateImpl(v)
        result = v.stringifiedValue

iterator pairs*(p: Profiler): tuple[key, value: string] =
    for k, v in p.values:
        if v.isDirty: v.updateImpl(v)
        yield (k, v.stringifiedValue)

template len*(p: Profiler): int = p.values.len

template `value=`*[T](ds: ProfilerDataSource[T], v: T) =
    ds.mValue = v
    ds.isDirty = true

template value*[T](ds: ProfilerDataSource[T]): T = ds.mValue

template inc*(ds: ProfilerDataSource[int]) =
    inc ds.mValue
    ds.isDirty = true

template dec*(ds: ProfilerDataSource[int]) =
    dec ds.mValue
    ds.isDirty = true
