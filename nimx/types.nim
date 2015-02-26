

type Coord* = float32
type ColorComponent = float32

type Point* = tuple[x, y: Coord]
type Size* = tuple[width, height: Coord]
type Rect* = tuple[origin: Point, size: Size]
type Color* = tuple[r, g, b, a: ColorComponent]
type Transform3D = distinct array[16, Coord]

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

proc newRect*(x, y, w, h: Coord): Rect =
    result.origin = newPoint(x, y)
    result.size = newSize(w, h)

proc newColor*(r, g, b: ColorComponent, a: ColorComponent = 1.0): Color =
    result.r = r
    result.g = g
    result.b = b
    result.a = a

type ButtonState* = enum
    bsUnknown, bsUp, bsDown

