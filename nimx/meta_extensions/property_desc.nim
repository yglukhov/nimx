import macros, tables, typetraits
import nimx/class_registry

export class_registry

type
  PropertyDesc* = tuple
    name: string
    attributes: Table[string, NimNode]

var props {.compileTime.} = initTable[string, seq[PropertyDesc]]()

proc hasAttr*(d: PropertyDesc, attr: string): bool =
  attr in d.attributes

iterator propertyDescs*(typdesc: NimNode): PropertyDesc =
  let k = $typdesc
  if k in props:
    for p in props[k]:
      yield p

proc addPropertyAttr(d: var PropertyDesc, a: NimNode) =
  case a.kind
  of nnkIdent:
    d.attributes[$a] = nil
  of nnkExprEqExpr:
    a[0].expectKind(nnkIdent)
    d.attributes[$a[0]] = a[1]
  of nnkStmtList:
    for c in a: addPropertyAttr(d, c)
  of nnkCall:
    a[0].expectKind(nnkIdent)
    assert(a.len == 2)
    var b = a[1]
    if b.kind == nnkStmtList:
      assert(b.len == 1)
      b = b[0]
    d.attributes[$a[0]] = b
  of nnkProcDef:
    d.attributes[$a.name] = a
  else:
    echo "Unexpected attr kind: ", treeRepr(a)
    assert(false)

proc parsePropertyDescs(properties: NimNode): seq[PropertyDesc] =
  result = @[]
  for p in properties:
    case p.kind
    of nnkStmtList:
      for c in p: result.add(parsePropertyDescs(c))
    of nnkIdent:
      var pd: PropertyDesc
      pd.name = $p
      pd.attributes = initTable[string, NimNode]()
      result.add(pd)
    of nnkCall:
      var pd: PropertyDesc
      pd.name = $p[0]
      pd.attributes = initTable[string, NimNode]()
      for i in 1 ..< p.len:
        addPropertyAttr(pd, p[i])
      result.add(pd)
    of nnkDiscardStmt:
      discard
    else:
      echo "Unexpected property desc kind: ", treeRepr(p)
      assert(false)

proc inheritFrom*(n: NimNode): NimNode {.compileTime.}=
  let impl = n.getImpl
  var inherit: NimNode
  if impl[2].kind == nnkRefTy:
    inherit = impl[2][0][1]

  if impl[2].kind == nnkObjectTy:
    inherit = impl[2][1]

  if inherit.kind == nnkOfInherit:
    return inherit[0]

  error "Unknown type " & $n

macro properties*(typdesc: typed{nkSym}, body: untyped): untyped =
  let k = $typdesc
  assert(k notin props)
  props[k] = parsePropertyDescs(body)
