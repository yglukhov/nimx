import macros

proc replaceIf*(inNode, withNode: NimNode, predicate: proc(n: NimNode): bool) =
    ## Recursively replaces all nodes matching `predicate` in `inNode` with
    ## `withNode`.
    var i = 0
    for c in inNode:
        if predicate(c):
            inNode[i] = withNode
        else:
            replaceIf(c, withNode, predicate)
        inc i

macro staticFor*(cond: untyped, body: untyped): untyped =
    cond.expectKind(nnkInfix)
    assert($cond[0] == "in")
    cond[1].expectKind(nnkIdent)
    let counterName = $cond[1]

    result = newNimNode(nnkStmtList)
    if cond.len == 3 and cond[2].kind == nnkBracket:
        for c in cond[2]:
            let copiedBody = body.copyNimTree()
            copiedBody.replaceIf(c) do(n: NimNode) -> bool:
                result = n.kind == nnkIdent and $n == counterName
            result.add(copiedBody)
    else:
        for i in 2 ..< cond.len:
            let subject = cond[i]
            let copiedBody = body.copyNimTree()
            copiedBody.replaceIf(subject) do(n: NimNode) -> bool:
                result = n.kind == nnkIdent and $n == counterName
            result.add(copiedBody)

when isMainModule:
    import typetraits

    proc testProc() =
        block:
            var s = newSeq[string]()
            staticFor t in [int, float]:
                s.add(t.name)
            doAssert(s.len == 2)
            doAssert(s[0] == "int")
            doAssert(s[1] == "float")

        block:
            var s = newSeq[string]()

            template doTheTest(args: varargs[untyped]) =
                staticFor t in args:
                    s.add(t.name)

            doTheTest(int, float)
            doAssert(s.len == 2)
            doAssert(s[0] == "int")
            doAssert(s[1] == "float")

    testProc()
