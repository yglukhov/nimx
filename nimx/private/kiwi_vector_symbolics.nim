import kiwi

proc `==`*[I](a: array[I, Expression], b: array[I, Expression]): array[I, Constraint] =
    for i in 0 ..< a.len:
        result[i] = a[i] == b[i]
