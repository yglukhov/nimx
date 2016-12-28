# This is a table implementation that is more native to JS. It has a lot of
# limitations as to key and value types. Please use with caution.

when not defined(js):
    import tables
    export tables
    type SimpleTable*[TKey, TVal] = TableRef[TKey, TVal]
    template newSimpleTable*(TKey, TVal: typedesc): SimpleTable[TKey, TVal] = newTable[TKey, TVal]()
else:
    type SimpleTable*[TKey, TVal] = ref object
        dummyk: TKey
        dummyv: TVal
    proc newSimpleTable*(TKey, TVal: typedesc): SimpleTable[TKey, TVal] {.importc: "new Object".}

    proc `[]`*[A, B](t: SimpleTable[A, B]; k: A): B {.importcpp: "#[#]".}
    proc `[]=`*[A, B](t: SimpleTable[A, B]; k: A, v: B) {.importcpp: "#[#]=#".}

    proc keyInTable[A, B](k: A, t: SimpleTable[A, B]): bool {.importcpp: "(# in #)".}
    template hasKey*[A, B](t: SimpleTable[A, B], k: A): bool = keyInTable(k, t)

when isMainModule:
    let t = newSimpleTable(int, int)
    t[1] = 123
    doAssert(t[1] == 123)
    doAssert(t.hasKey(1))
