# This is a table implementation that is more native to JS. It has a lot of
# limitations as to key and value types. Please use with caution.

when not defined(js):
    import tables
    export tables
    type SimpleTable*[TKey, TVal] = TableRef[TKey, TVal]
    template newSimpleTable*(TKey, TVal: typedesc): SimpleTable[TKey, TVal] = newTable[TKey, TVal]()
else:
    type SimpleTable*[TKey, TVal] = ref object
    proc newSimpleTable*(TKey, TVal: typedesc): SimpleTable[TKey, TVal] {.importc: "new Object".}

    {.push stackTrace: off.}
    proc getVal(t, k: ref RootObj): ref RootObj = {.emit: "`result` = `t`[`k`];".}
    proc setVal(t, k, v: ref RootObj) = {.emit: "`t`[`k`] = `v`;".}
    proc hasKeyImpl(t, k: ref RootObj): bool = {.emit: "`result` = (`k` in `t`);".}
    {.pop.}

    proc dummySimpleTableValueType*[A, B](t: SimpleTable[A, B]): B = discard

    template `[]`*[A, B](t: SimpleTable[A, B]; k: A): B =
        cast[type(t.dummySimpleTableValueType())](getVal(cast[ref RootObj](t), cast[ref RootObj](k)))

    template `[]=`*[A, B](t: SimpleTable[A, B]; k: A, v: B) = setVal(cast[ref RootObj](t), cast[ref RootObj](k), cast[ref RootObj](v))

    template hasKey*[A, B](t: SimpleTable[A, B], k: A): bool = hasKeyImpl(cast[ref RootObj](t), cast[ref RootObj](k))

when isMainModule:
    let t = newSimpleTable(int, int)
    t[1] = 123
    doAssert(t[1] == 123)
    doAssert(t.hasKey(1))
