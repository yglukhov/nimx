import tables

type
    ProfilerDataSourceBase = ref object of RootObj
        stringifiedValue: string
        isDirty: bool

    ProfilerDataSource*[T] = ref object of ProfilerDataSourceBase
        mValue: T

    Profiler* = ref object
        values: Table[string, ProfilerDataSourceBase]
        enabled*: bool

method update(ds: ProfilerDataSourceBase) {.base.} =
    ds.isDirty = false

method update[T](ds: ProfilerDataSource[T]) =
    ds.stringifiedValue = $ds.mValue
    shallow(ds.stringifiedValue)
    ds.isDirty = false

var gProfiler : Profiler

proc newProfiler*(): Profiler =
    result.new()
    result.values = initTable[string, ProfilerDataSourceBase]()
    when not defined(release):
        result.enabled = true

proc newDataSource*[T](p: Profiler, name: string): ProfilerDataSource[T] =
    result.new()
    result.stringifiedValue = ""
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

iterator pairs*(p: Profiler): tuple[key, value: string] =
    for k, v in p.values:
        if v.isDirty: v.update()
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
