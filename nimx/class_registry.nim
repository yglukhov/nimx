import tables, typetraits, macros, variant

macro superType(t: typed): expr =
    # let ty = getImpl(t.symbol)
    # echo "n: ", treeRepr(t)
    # echo "ty: ",                treeRepr(getType(t))

    let ty = getType(t)
    let refSym = ty[1][0]
    # echo "tysssss: ",                treeRepr(refSym)
    # echo "ty ...: ",            treeRepr(getType(getType(t)[1][1]))
    # echo "ty .......: ",        treeRepr(getType(getType(t)[1][1])[1])

    result = getType(ty[1][1])[1]
    result = newNimNode(nnkBracketExpr).add(refSym, result)
    #echo "impl: ", treeRepr(ty)
    #result = ty[2][0][1][0]

method className*(o: RootRef): string {.base.} = discard

type ClassInfo = tuple
    creatorProc: proc(): RootRef {.nimcall.}
    typ: TypeId

var classFactory = initTable[string, ClassInfo]()
var superTypeRelations = initTable[TypeId, TypeId]()

{.push, stackTrace: off.}

proc registerTypeRelation(a: typedesc) =
    type ParentType = superType(a)
    if not superTypeRelations.hasKeyOrPut(getTypeId(a), getTypeId(ParentType)):
        when RootRef isnot ParentType:
            registerTypeRelation(ParentType)

proc isTypeOf(tself, tsuper: TypeId): bool =
    var t = tself
    while t != tsuper and t != 0:
        t = superTypeRelations.getOrDefault(t)
    result = t != 0

proc isSubtypeOf(tself, tsuper: TypeId): bool = tself != tsuper and isTypeOf(tself, tsuper)

{.pop.}

template registerClass*(a: typedesc) =
    const TName = typetraits.name(a)
    method className*(o: a): string = TName
    registerTypeRelation(a)
    #superTypeRelations[getTypeId(a)] = getTypeId(superType(a))
    var info: ClassInfo
    info.creatorProc = proc(): RootRef =
        var r: a
        r.new()
        result = r
    info.typ = getTypeId(a)
    classFactory[TName] = info

template isClassRegistered*(name: string): bool = name in classFactory

proc newObjectOfClass*(name: string): RootRef =
    let c = classFactory.getOrDefault(name)
    if c.creatorProc.isNil: raise newException(Exception, "Class '" & name & "' is not registered")
    result = c.creatorProc()

iterator registeredClasses*(): string =
    for k in classFactory.keys: yield k

iterator registeredClassesOfType*(T: typedesc): string =
    const typ = getTypeId(T)
    for k, v in pairs(classFactory):
        if isTypeOf(v.typ, typ):
            yield k

iterator registeredSubclassesOfType*(T: typedesc): string =
    const typ = getTypeId(T)
    for k, v in pairs(classFactory):
        if isSubtypeOf(v.typ, typ):
            yield k

when isMainModule:
    type A = ref object of RootRef
    type B = ref object of A
    type C = ref object of B

    echo "typeId RootRef: ", getTypeId(RootRef)
    echo "typeId A: ", getTypeId(A)
    echo "typeId B: ", getTypeId(B)

    echo "typeId superType(A): ", getTypeId(superType(A))
    echo "typeId superType(B): ", getTypeId(superType(B))

    registerClass(A)
    registerClass(B)
    registerClass(C)

    doAssert(superTypeRelations[getTypeId(A)] == getTypeId(RootRef))
    doAssert(superTypeRelations[getTypeId(B)] == getTypeId(A))

    proc isSubtypeOf(tself, tsuper: string): bool =
        isSubtypeOf(classFactory[tself].typ, classFactory[tsuper].typ)

    doAssert("B".isSubtypeOf("A"))
    doAssert(not "A".isSubtypeOf("B"))

    echo "Supertype relations: ", superTypeRelations

    echo "Subclasses of RootRef:"
    for t in registeredClassesOfType(RootRef):
        echo t
    echo "Subclasses of A:"
    for t in registeredClassesOfType(A):
        echo t
    echo "Subclasses of B:"
    for t in registeredClassesOfType(B):
        echo t

    let a = newObjectOfClass("A")
    let b = newObjectOfClass("B")
    let c = newObjectOfClass("C")

    doAssert(a.className() == "A")
    doAssert(b.className() == "B")
    doAssert(c.className() == "C")
