
template lowerBoundIt*[T](arr: openarray[T], a, b: int, predicate: untyped): int =
  var result {.gensym.} = a
  var count = b - a + 1
  var step, pos: int
  while count != 0:
    step = count div 2
    pos = result + step
    template it: T {.inject.} = arr[pos]
    if predicate:
      result = pos + 1
      count -= step + 1
    else:
      count = step
  result
