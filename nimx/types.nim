import math

type Coord* = float32
type ColorComponent* = float32

type Point* = tuple[x, y: Coord]
type Size* = tuple[width, height: Coord]
type Rect* = tuple[origin: Point, size: Size]
type Color* = tuple[r, g, b, a: ColorComponent]

proc x*(r: Rect): Coord = r.origin.x
proc y*(r: Rect): Coord = r.origin.y
proc width*(r: Rect): Coord = r.size.width
proc height*(r: Rect): Coord = r.size.height

proc `x=`*(r: var Rect, v: Coord) = r.origin.x = v
proc `y=`*(r: var Rect, v: Coord) = r.origin.y = v
proc `width=`*(r: var Rect, v: Coord) = r.size.width = v
proc `height=`*(r: var Rect, v: Coord) = r.size.height = v

proc minX*(r: Rect): Coord = r.x
proc maxX*(r: Rect): Coord = r.x + r.width
proc minY*(r: Rect): Coord = r.y
proc maxY*(r: Rect): Coord = r.y + r.height

proc newPoint*(x, y: Coord): Point = (x: x, y: y)

const zeroPoint* = newPoint(0, 0)

proc newSize*(w, h: Coord): Size = (width: w, height: h)

const zeroSize* = newSize(0, 0)

proc newRect*(o: Point, s: Size = zeroSize): Rect = (origin: o, size: s)
proc newRect*(x, y, w, h: Coord): Rect = newRect(newPoint(x, y), newSize(w, h))

proc rect*(o: Point, s: Size = zeroSize): Rect = (origin: o, size: s)
proc rect*(x, y, w, h: Coord): Rect = rect(newPoint(x, y), newSize(w, h))

proc newRectWithPoints*(p1, p2: Point): Rect =
  let minX = min(p1.x, p2.x)
  let minY = min(p1.y, p2.y)
  let maxX = max(p1.x, p2.x)
  let maxY = max(p1.y, p2.y)
  result = newRect(minX, minY, maxX - minX, maxY - minY)

proc union*(r : var Rect, x , y : Coord) =
  if x < r.origin.x:
    r.size.width += r.origin.x - x
    r.origin.x = x
  elif x > r.origin.x + r.size.width:
    r.size.width = x - r.origin.x
  if y < r.origin.y:
    r.size.height += r.origin.y - y
    r.origin.y = y
  elif y > r.origin.y + r.size.height:
    r.size.height = y - r.origin.y

proc union*(r : var Rect, p: Point) =
  r.union(p.x, p.y)

proc centerPoint*(r: Rect) : Point =
  newPoint(r.origin.x + r.size.width / 2, r.origin.y + r.size.height / 2)

const zeroRect* = newRect(zeroPoint, zeroSize)

proc inset*(r: Rect, dx, dy: Coord): Rect = newRect(r.x + dx, r.y + dy, r.width - dx * 2, r.height - dy * 2)
proc inset*(r: Rect, d: Coord): Rect = inset(r, d, d)

proc newColor*(r, g, b: ColorComponent, a: ColorComponent = 1.0): Color =
  (r: r, g: g, b: b, a: a)

template newColorB*(r, g, b: int, a: int = 255): Color = newColor(r / 255, g / 255, b / 255, a / 255)

proc newGrayColor*(g: ColorComponent, a: ColorComponent = 1.0): Color = newColor(g, g, g, a)

proc whiteColor*(): Color = newGrayColor(1)
proc blackColor*(): Color = newGrayColor(0)
proc grayColor*(): Color = newGrayColor(0.75)
proc clearColor*(): Color = newGrayColor(0, 0)

proc `*`*(c: Color, v: float32): Color =
  (r: c.r * v, g: c.g * v, b: c.b * v, a: c.a * v)

proc `+`*(c: Color, v: float32): Color =
  (r: c.r + v, g: c.g + v, b: c.b + v, a: c.a + v)

proc `+`*(c1, c2: Color): Color =
  (r: c1.r + c2.r, g: c1.g + c2.g, b: c1.b + c2.b, a: c1.a + c2.a)

proc `-`*(c1, c2: Color): Color =
  (r: c1.r - c2.r, g: c1.g - c2.g, b: c1.b - c2.b, a: c1.a - c2.a)

proc minCorner*(r: Rect): Point = r.origin
proc maxCorner*(r: Rect): Point = newPoint(r.maxX, r.maxY)

proc `+`*(p1, p2: Point): Point =
  newPoint(p1.x + p2.x, p1.y + p2.y)

proc `*`*(p1: Point, s: float32): Point =
  newPoint(p1.x * s, p1.y * s)

proc `/`*(p1: Point, s: float32): Point =
  newPoint(p1.x / s, p1.y / s)

proc `-`*(p1, p2: Point): Point =
  newPoint(p1.x - p2.x, p1.y - p2.y)

proc `+=`*(p1: var Point, p2: Point) =
  p1.x += p2.x
  p1.y += p2.y

proc `-=`*(p1: var Point, p2: Point) =
  p1.x -= p2.x
  p1.y -= p2.y

proc `+`*(s1, s2: Size): Size =
  newSize(s1.width + s2.width, s1.height + s2.height)

proc `-`*(s1, s2: Size): Size =
  newSize(s1.width - s2.width, s1.height - s2.height)

proc `*`*(s: Size, v: float32): Size =
  (width: s.width * v, height: s.height * v)

proc `/`*(s: Size, v: float32): Size =
  (width: s.width / v, height: s.height / v)

proc distanceTo*(p : Point, to: Point) : float32 =
  result = sqrt(pow(p.x - to.x, 2) + pow(p.y - to.y, 2))

proc contains*(r: Rect, p: Point): bool =
  p.x >= r.x and p.x <= r.maxX and p.y >= r.y and p.y <= r.maxY

template inRect*(p: Point, r: Rect): bool = p in r

# return angle between 0 and 360 degrees
proc vectorAngle*(p: Point, to: Point) : float32 =
  let v = to - p
  var angle = radToDeg(arctan2(v.y, v.x));
  if angle < 0:
    angle = angle + float(360)
  result = angle

proc centerInRect*(s: Size, r: Rect): Point =
  # Returns origin of rect of size s, centered in rect r.
  # The result may be outside of rect r, if s is bigger than size of r.
  result.x = r.origin.x + (r.width - s.width) / 2
  result.y = r.origin.y + (r.height - s.height) / 2

proc centerInRect*(centerThis: Rect, inThis: Rect): Rect =
  # Returns `centerThis` centered in `inThis`
  # The result may be outside of rect `inThis`, if `centerInThis` is bigger than size of `inThis`.
  result.size = centerThis.size
  result.origin = centerInRect(centerThis.size, inThis)

proc intersect*(r: Rect, c: Rect): bool =
  if r.minX < c.maxX and c.minX < r.maxX and r.minY < c.maxY and c.minY < r.maxY:
    result = true

proc trim*(r, c: Rect): Rect =
  ## Trim r with c
  result = r
  if result.x < c.x:
    result.size.width -= c.x - result.x
    result.x = c.x
  if result.maxX > c.maxX:
    result.width = c.maxX - result.x

  if result.y < c.y:
    result.size.height -= c.y - result.y
    result.x = c.x
  if result.maxY > c.maxY:
    result.height = c.maxY - result.y
