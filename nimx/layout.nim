import macros, strutils
import view
import kiwi
import private.kiwi_vector_symbolics

import kiwi / [ symbolics, strength ]
export symbolics, strength, kiwi_vector_symbolics
export superPHS, selfPHS, prevPHS, nextPHS

proc isViewDesc(n: NimNode): bool =
    n.kind == nnkPrefix and $n[0] == "-"

proc collectAllViewNodes(body: NimNode, allViews: var seq[NimNode], childParentRelations: var seq[int]) =
    var parentId = allViews.len - 1
    for c in body:
        if c.isViewDesc():
            allViews.add(c)
            childParentRelations.add(parentId)
            collectAllViewNodes(c[2], allViews, childParentRelations)

proc getIdFromViewDesc(viewDesc: NimNode): NimNode =
    let header = viewDesc[1]
    if header.kind == nnkCommand and header.len == 2 and header[1].kind == nnkIdent:
        result = header[1]

proc getTypeFromViewDesc(viewDesc: NimNode): NimNode =
    let header = viewDesc[1]
    if header.kind == nnkCommand and header.len == 2 and header[0].kind == nnkIdent:
        result = header[0]
    elif header.kind == nnkIdent:
        result = header
    else:
        assert(false, "Invalid node")

const placeholderNames = ["super", "self", "prev", "next"]
const attributeNames = [
    "width", "height",
    "left", "right",
    "x", "y",
    "top", "bottom",
    "leading", "trailing",
    "centerX", "centerY",
    "origin",
    "center",
    "size"
    ]

proc transformConstraintNode(cn, subject: NimNode): NimNode =
    result = cn
    case cn.kind
    of nnkIdent:
        let n = $cn
        if n in attributeNames:
            result = newDotExpr(bindSym"selfPHS", cn)
        elif not subject.isNil and n in placeholderNames:
            result = newDotExpr(newIdentNode(n & "PHS"), subject)
    of nnkDotExpr:
        if cn.len == 2 and cn[0].kind == nnkIdent and cn[1].kind == nnkIdent:
            let a = $cn[0]
            var done = false
            if a in placeholderNames:
                result[0] = newIdentNode(a & "PHS")
                done = true
    else:
        for i in 0 ..< cn.len:
            cn[i] = transformConstraintNode(cn[i], subject)

template setControlHandlerBlock(c: View, p: untyped, a: untyped) =
    when compiles(c.p(nil)):
        c.p() do(): a
    else:
        c.p = proc() =
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

proc convertDoToProc(n: NimNode): NimNode =
    expectKind(n, nnkDo)
    result = newProc()
    result.params = n.params
    result.body = n.body

proc layoutAux(rootView: NimNode, body: NimNode): NimNode =
    var views = @[body]
    var childParentRelations = @[-1]
    collectAllViewNodes(body, views, childParentRelations)

    let numViews = views.len

    var types = newSeq[NimNode](numViews)
    for i in 1 ..< numViews: types[i] = getTypeFromViewDesc(views[i])

    var ids = newSeq[NimNode](numViews)
    ids[0] = rootView
    for i in 1 ..< numViews:
        let id = getIdFromViewDesc(views[i])
        if id.kind == nnkIdent:
            ids[i] = id
        else:
            ids[i] = newIdentNode("layout_" & $types[i] & "_" & $i)

    result = newNimNode(nnkStmtList)
    let idDefinitions = newNimNode(nnkLetSection)

    for i in 1 ..< numViews:
        idDefinitions.add(newIdentDefs(ids[i], newEmptyNode(), newCall("new", types[i])))
    result.add(idDefinitions)

    for i in 1 ..< numViews:
        result.add(newCall("init", ids[i], newIdentNode("zeroRect")))

    for i in 1 ..< numViews:
        result.add(newCall("addSubview", ids[childParentRelations[i]], ids[i]))

    for i in 1 ..< numViews:
        views[i] = views[i][2]

    for i in 0 ..< numViews:
        for p in views[i]:
            if p.kind == nnkCall and p.len == 2 and p[0].kind == nnkIdent:
                let prop = $p[0]
                if prop.len > 2 and prop.startsWith("on") and prop[2].isUpperAscii:
                    if p[1].kind == nnkDo:
                        result.add(newCall(bindSym"setControlHandlerLambda", ids[i], p[0], p[1]))
                    else:
                        result.add(newCall(bindSym"setControlHandlerBlock", ids[i], p[0], p[1]))
                else:
                    if p[1].kind == nnkDo:
                        p[1] = convertDoToProc(p[1])
                    result.add(newAssignment(newDotExpr(ids[i], p[0]), p[1]))
            elif p.kind == nnkInfix:
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
                if expression[1].kind == nnkIdent:
                    subject = expression[1]

                result.add(newCall(bindSym"addConstraintWithStrength", ids[i], transformConstraintNode(expression, subject), strength))
            elif p.kind == nnkStmtList and p.len == 1 and p[0].kind == nnkDiscardStmt:
                discard
            elif p.kind == nnkDiscardStmt:
                discard
            elif p.isViewDesc():
                discard
            else:
                echo "Unknown node:"
                echo repr(p)
                assert(false)

    echo "result: ", repr(result)
    # echo "ids: ", ids

macro makeLayout*(v: View, e: untyped): untyped = # Experimental
    echo treeRepr(e)
    layoutAux(v, e)
