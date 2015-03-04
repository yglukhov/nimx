

type Coord* = float32
type ColorComponent = float32

type Point* = tuple[x, y: Coord]
type Size* = tuple[width, height: Coord]
type Rect* = tuple[origin: Point, size: Size]
type Color* = tuple[r, g, b, a: ColorComponent]

proc x*(r: Rect): Coord = r.origin.x
proc y*(r: Rect): Coord = r.origin.y
proc width*(r: Rect): Coord = r.size.width
proc height*(r: Rect): Coord = r.size.height

proc minX*(r: Rect): Coord = r.x
proc maxX*(r: Rect): Coord = r.x + r.width
proc minY*(r: Rect): Coord = r.y
proc maxY*(r: Rect): Coord = r.y + r.height

proc newPoint*(x, y: Coord): Point =
    result.x = x
    result.y = y

proc newSize*(w, h: Coord): Size =
    result.width = w
    result.height = h

proc newRect*(o: Point, s: Size): Rect =
    result.origin = o
    result.size = s

proc newRect*(x, y, w, h: Coord): Rect =
    newRect(newPoint(x, y), newSize(w, h))

proc newColor*(r, g, b: ColorComponent, a: ColorComponent = 1.0): Color =
    result.r = r
    result.g = g
    result.b = b
    result.a = a

proc minCorner*(r: Rect): Point = r.origin
proc maxCorner*(r: Rect): Point = newPoint(r.maxX, r.maxY)

proc `>`*(p1, p2: Point): bool =
    # Component-wise comparison
    p1.x > p2.x and p1.y > p2.y

proc `>=`*(p1, p2: Point): bool =
    # Component-wise comparison
    p1.x >= p2.x and p1.y >= p2.y

proc `<`*(p1, p2: Point): bool =
    # Component-wise comparison
    p1.x < p2.x and p1.y < p2.y

proc `<=`*(p1, p2: Point): bool =
    # Component-wise comparison
    p1.x <= p2.x and p1.y <= p2.y


proc `+`*(p1, p2: Point): Point =
    newPoint(p1.x + p2.x, p1.y + p2.y)

proc `-`*(p1, p2: Point): Point =
    newPoint(p1.x - p2.x, p1.y - p2.y)


proc `+`*(s1, s2: Size): Size =
    newSize(s1.width + s2.width, s1.height + s2.height)

proc `-`*(s1, s2: Size): Size =
    newSize(s1.width - s2.width, s1.height - s2.height)


proc inRect*(p: Point, r: Rect): bool =
    p >= r.origin and p <= r.maxCorner

proc centerInRect*(s: Size, r: Rect): Point =
    # Returns origin of rect of size s, centered in rect r.
    # The result may be outside of rect r, if s is bigger than size of r.
    result.x += (r.width - s.width) / 2
    result.y += (r.height - s.height) / 2
