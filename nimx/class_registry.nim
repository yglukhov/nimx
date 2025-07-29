import tables, macros, variant
import typetraits except getTypeid, Typeid # see https://github.com/nim-lang/Nim/pull/13305

proc skipPtrRef(n: NimNode): NimNode =
  let ty = getImpl(n)
  result = n
  if ty[2].kind in {nnkRefTy, nnkPtrTy} and ty[2][0].kind == nnkSym:
    result = ty[2][0].skipPtrRef()

proc nodeTypedefInheritsFrom(n: NimNode): NimNode =
  n.expectKind(nnkTypeDef)
  if n[2].kind == nnkRefTy and n[2][0].kind == nnkObjectTy and n[2][0][1].kind == nnkOfInherit:
    result = n[2][0][1][0]

proc `*`(s: string, i: int): string {.compileTime, used.} =
  result = ""
  for ii in 0 ..< i: result &= s

proc superTypeAux(t: NimNode, indent: int): NimNode =
  doAssert(indent < 10, "Recursion too deep")

  template superTypeAux(t: NimNode): NimNode = superTypeAux(t, indent + 1)
  proc log(args: varargs[string, `$`]) =
    discard
    # echo "- ", "  " * indent, args.join(" ")

  log "superTypeAux: ", treeRepr(t)
  case t.kind
  of nnkSym:
    if $t == "RootRef": return t
    let ty = getTypeImpl(t)
    log "TypeKind: ", ty.typeKind
    result = superTypeAux(ty)
  of nnkBracketExpr:
    result = superTypeAux(getImpl(t[1]))
  of nnkTypeDef:
    result = nodeTypedefInheritsFrom(t)
    if result.isNil:
      result = superTypeAux(getTypeInst(t[2]))
  of nnkRefTy:
    result = superTypeAux(getTypeImpl(t[^1]))
  of nnkObjectTy:
    t[1].expectKind(nnkOfInherit)
    result = t[1][0]
  else:
    log "unknown node : ", treeRepr(t)
    doAssert(false, "Unknown node")

  log "result ", repr(result)

macro superType*(t: typed): untyped = superTypeAux(t, 0)

method className*(o: RootRef): string {.base, gcsafe.} = discard
method classTypeId*(o: RootRef): TypeId {.base, gcsafe.} = getTypeId(RootRef)

type ClassInfo = tuple
  creatorProc: proc(): RootRef {.nimcall.}
  typ: TypeId

var classFactory {.threadvar.}: Table[string, ClassInfo]
var superTypeRelations {.threadvar.}: Table[TypeId, TypeId]
classFactory = initTable[string, ClassInfo]()
superTypeRelations = initTable[TypeId, TypeId]()

{.push, stackTrace: off.}

proc registerTypeRelation(a: typedesc) =
  type ParentType = superType(a)
  if not superTypeRelations.hasKeyOrPut(getTypeId(a), getTypeId(ParentType)):
    when (RootRef isnot ParentType) and (RootObj isnot ParentType):
      registerTypeRelation(ParentType)

proc isTypeOf(tself, tsuper: TypeId): bool =
  var t = tself
  while t != tsuper and t != 0:
    t = superTypeRelations.getOrDefault(t)
  result = t != 0

proc isSubtypeOf(tself, tsuper: TypeId): bool = tself != tsuper and isTypeOf(tself, tsuper)

{.pop.}

template registerClass*(a: typedesc, creator: proc(): RootRef) =
  const TName = typetraits.name(a)
  const tid = getTypeId(a)
  method className*(o: a): string = TName
  method classTypeId*(o: a): TypeId = tid
  registerTypeRelation(a)
  var info: ClassInfo
  info.creatorProc = creator
  info.typ = tid
  classFactory[TName] = info

template registerClass*(a: typedesc) =
  let c = proc(): RootRef =
    var res: a
    res.new()
    return res
  registerClass(a, c)

template isClassRegistered*(name: string): bool = name in classFactory

proc newObjectOfClass*(name: string): RootRef =
  {.gcsafe.}:
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
  echo "typeId RootObj: ", getTypeId(RootObj)
  echo "typeId A: ", getTypeId(A)
  echo "typeId B: ", getTypeId(B)

  echo "typeId superType(A): ", getTypeId(superType(A))
  echo "typeId superType(B): ", getTypeId(superType(B))

  template sameType(t1, t2: typedesc): bool =
    t1 is t2 and t2 is t1

  assert sameType(superType(A), RootRef)
  assert sameType(superType(B), A)
  assert sameType(superType(C), B)

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

  doAssert(a.classTypeId() == getTypeId(A))
  doAssert(b.classTypeId() == getTypeId(B))
  doAssert(c.classTypeId() == getTypeId(C))

  proc getSupertypeTypeId(a: typedesc): TypeId =
    type ParentType = superType(a)
    const id = getTypeId(ParentType)
    return id

  doAssert(getSupertypeTypeId(A) == getTypeId(RootRef))
