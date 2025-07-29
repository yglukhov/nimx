import kiwi

proc equalConstraints(a, b: openarray[Expression], result: var openarray[Constraint]) =
  for i in 0 ..< a.len:
    result[i] = a[i] == b[i]

proc ltConstraints(a, b: openarray[Expression], result: var openarray[Constraint]) =
  for i in 0 ..< a.len:
    result[i] = a[i] <= b[i]

proc `==`*[I](a, b: array[I, Expression]): array[I, Constraint] {.inline.} =
  equalConstraints(a, b, result)

proc `<=`*[I](a, b: array[I, Expression]): array[I, Constraint] {.inline.} =
  ltConstraints(a, b, result)

template defineMath(op: untyped) =
  proc private(a: openarray[Expression], b: float32, result: var openarray[Expression]) =
    for i in 0 ..< a.len:
      result[i] = op(a[i], b)

  proc op*[I](a: array[I, Expression], b: float32): array[I, Expression] {.inline.} =
    private(a, b, result)

defineMath(`+`)
defineMath(`-`)
