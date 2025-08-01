import macros, strutils
import view, layout_vars
import kiwi
import private/kiwi_vector_symbolics

import kiwi / [ symbolics, strength ]
export symbolics, strength, kiwi_vector_symbolics
export layout_vars

proc isViewDescNodeAux(n: NimNode): bool =
  n.kind == nnkPrefix and $n[0] == "-"

proc identOrSym(n: NimNode): bool = n.kind in {nnkIdent, nnkSym, nnkOpenSymChoice, nnkClosedSymChoice}

proc isViewDescNode(n: NimNode): bool =
  isViewDescNodeAux(n) or
    (n.kind == nnkInfix and n.len == 4 and n[0].identOrSym and $n[0] == "as" and isViewDescNodeAux(n[1]) and n[2].identOrSym)

proc isPropertyNode(n: NimNode): bool =
  n.kind == nnkCall and n.len == 2# and n[0].identOrSym

proc isConstraintNode(n: NimNode): bool =
  if n.kind == nnkInfix:
    var op = $n[0]
    if op == "@":
      op = $n[1][0]
    result = op in ["==", ">=", "<="]

proc isDiscardNode(n: NimNode): bool =
  n.kind == nnkDiscardStmt or (n.kind == nnkStmtList and n.len == 1 and n[0].kind == nnkDiscardStmt)

proc getIdFromViewDesc(n: NimNode): NimNode =
  if n.kind == nnkInfix: # - View as v:
    result = n[2]
  # let header = viewDesc[1]
  # if header.kind == nnkCommand and header.len == 2 and header[1].identOrSym:
  #   result = header[1]

proc getInitializerFromViewDesc(n: NimNode): NimNode =
  ## Returns initializer node. It is either a type or expression that returns a view

  if n.kind == nnkPrefix: # - Initializer:
    result = n[1]
  elif n.kind == nnkInfix: # - Initializer as v:
    result = n[1][1]
  else:
    assert(false, "Invalid node")

proc getBodyFromViewDesc(n: NimNode): NimNode =
  if n.kind == nnkPrefix: # - View: body
    result = n[2]
  elif n.kind == nnkInfix: # - View as v: body
    result = n[3]
  else:
    assert(false, "Invalid node")

proc collectAllViewNodes(body: NimNode, allViews: var seq[NimNode], childParentRelations: var seq[int]) =
  var parentId = allViews.len - 1
  for c in body:
    if c.isViewDescNode():
      allViews.add(c)
      childParentRelations.add(parentId)
      collectAllViewNodes(getBodyFromViewDesc(c), allViews, childParentRelations)

const placeholderNames = ["super", "self", "prev", "next"]

proc fixupVectorOperand(n: NimNode) =
  if n.kind == nnkBracket:
    let newExpression = bindSym"newExpression"
    for i, c in n:
      n[i] = newCall(newExpression, c)

proc addPlaceholderToLeftOperand(n: NimNode): NimNode =
  result = n
  if n.identOrSym:
    result = newDotExpr(ident"selfPHS", n)

proc transformConstraintNodeAux(cn, subject: NimNode): NimNode =
  result = cn
  case cn.kind
  of nnkIdent, nnkSym:
    let n = $cn
    if not subject.isNil and n in placeholderNames:
      result = newDotExpr(ident(n & "PHS"), subject)
  of nnkDotExpr:
    if cn.len == 2 and cn[0].identOrSym and $cn[0] in placeholderNames:
      result[0] = ident($cn[0] & "PHS")
    else:
      result[0] = transformConstraintNodeAux(cn[0], subject)

    for i in 1 ..< cn.len:
      cn[i] = transformConstraintNodeAux(cn[i], subject)
  else:
    for i in 0 ..< cn.len:
      cn[i] = transformConstraintNodeAux(cn[i], subject)

proc transformConstraintNode(cn, subject: NimNode): NimNode =
  result = transformConstraintNodeAux(cn, subject)
  fixupVectorOperand(result[1])
  fixupVectorOperand(result[2])
  result[1] = addPlaceholderToLeftOperand(result[1])

template setControlHandlerBlock(c: View, p: untyped, a: untyped) =
  when compiles(c.p(nil)):
    c.p() do() {.gcsafe.}: a
  else:
    c.p = proc() {.gcsafe.} =
      a

template setControlHandlerLambda(c: View, p: untyped, a: untyped) =
  when compiles(c.p(a)):
    c.p(a)
  else:
    c.p = a

proc addConstraintWithStrength(v: View, c: Constraint, strength: float) =
  c.strength = clipStrength(strength)
  v.addConstraint(c)

proc addConstraintWithStrength(v: View, cc: openarray[Constraint], strength: float) =
  for c in cc: v.addConstraintWithStrength(c, strength)

# proc convertDoToProc(n: NimNode): NimNode =
#   expectKind(n, nnkDo)
#   result = newProc()
#   result.params = n.params
#   result.body = n.body

var uniqueIdCounter {.compileTime.} = 0

proc layoutAux(rootView: NimNode, body: NimNode): NimNode =
  var views = @[body]
  var childParentRelations = @[-1]
  collectAllViewNodes(body, views, childParentRelations)

  let numViews = views.len

  var initializers = newSeq[NimNode](numViews)
  for i in 1 ..< numViews: initializers[i] = getInitializerFromViewDesc(views[i])

  var ids = newSeq[NimNode](numViews)
  ids[0] = rootView
  for i in 1 ..< numViews:
    let id = getIdFromViewDesc(views[i])
    if id.identOrSym:
      ids[i] = id
    else:
      var typeName = ""
      if initializers[i].identOrSym:
        typeName = "_" & $initializers[i]

      ids[i] = newIdentNode("layout" & typeName & "_" & $i & "_" & $uniqueIdCounter)
      inc uniqueIdCounter

  result = newNimNode(nnkStmtList)
  let idDefinitions = newNimNode(nnkLetSection)

  for i in 1 ..< numViews:
    if initializers[i].identOrSym:
      # Explicit type. Need to create with new(). init() is called later.
      idDefinitions.add(newIdentDefs(ids[i], newEmptyNode(), newCall("new", initializers[i])))
    else:
      idDefinitions.add(newIdentDefs(ids[i], newEmptyNode(), initializers[i]))
  result.add(idDefinitions)

  # for i in 1 ..< numViews:
  #   if initializers[i].identOrSym: # Explicit type. Need to cal init()
  #     result.add(newCall("init", ids[i]))

  for i in 1 ..< numViews:
    result.add(newCall("addSubview", ids[childParentRelations[i]], ids[i]))

  for i in 1 ..< numViews:
    views[i] = getBodyFromViewDesc(views[i])

  for i in 0 ..< numViews:
    for p in views[i]:
      if p.isPropertyNode():
        let prop = $p[0]
        if prop.len > 2 and prop.startsWith("on") and prop[2].isUpperAscii:
          if p[1].kind == nnkDo:
            result.add(newCall(bindSym"setControlHandlerLambda", ids[i], p[0], p[1]))
          else:
            result.add(newCall(bindSym"setControlHandlerBlock", ids[i], p[0], p[1]))
        else:
          # It looks like newer nim doesn't require nnkDo to nnkProc conversion,
          # moreover it there will be a weird compilation error: "overloaded :anonymous leads to ambiguous calls"
          # if p[1].kind == nnkDo:
          #   p[1] = convertDoToProc(p[1])
          result.add(newAssignment(newDotExpr(ids[i], p[0]), p[1]))
      elif p.isConstraintNode():
        var op = $p[0]
        var strength: NimNode
        var expression = p
        if op == "@":
          expression = p[1]
          strength = p[2]
          op = $expression[0]
        else:
          strength = bindSym"REQUIRED"
        assert(op in ["==", ">=", "<="])

        var subject: NimNode
        if expression[1].identOrSym:
          subject = expression[1]

        result.add(newCall(bindSym"addConstraintWithStrength", ids[i], transformConstraintNode(expression, subject), strength))
      elif p.isDiscardNode():
        discard
      elif p.isViewDescNode():
        discard
      else:
        echo "Invalid AST in layout markup:"
        echo repr(p)
        assert(false)

  # echo "result: ", repr(result)
  # echo "ids: ", ids

macro makeLayout*(v: View, e: untyped): untyped = # Experimental
  # echo treeRepr(e)
  layoutAux(v, e)
