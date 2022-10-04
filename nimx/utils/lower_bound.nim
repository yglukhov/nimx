
template lowerBoundIt*[T](arr: openarray[T], a, b: int, predicate: untyped): int =
  block:
    var res = a
    var count = b - res + 1
    var step, pos: int
    while count != 0:
      step = count div 2
      pos = res + step
      template it: T {.inject.} = arr[pos]
      if predicate:
        res = pos + 1
        count -= step + 1
      else:
        count = step
    res
