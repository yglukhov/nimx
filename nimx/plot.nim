import std/strutils
import nimx/[
  context,
  control,
  event,
  font
 ]

type ModelXY*[T] = seq[tuple[x: T, y: T]]
  ## y=f(x) discrete data model

type ModelXYColor*[T] = seq[tuple[x: T, y: T, color: Color]]
  ## t=f(x) discrete data model with colored dots

type PlotXY* = ref object of Control
  ## Plotting widgets that implements rendering of "y=f(x)" function.
  title*: string
  labelX*: string
  labelY*: string
  boundary*: float32
  dotSize*: int
  gridstep*: float32
  drawMedian*: bool
  model*: ModelXYColor[float64]
  highlightedPoint: int
  modelBounds: tuple[minx: float64, maxx: float64, miny: float64, maxy: float64]
  scale: tuple[x: float64, y: float64]
  poly: seq[Coord]

proc modelBounds*(mxy: PlotXY): tuple[minx: float64, maxx: float64, miny: float64, maxy: float64] = mxy.modelBounds

proc updateModel(mxy: PlotXY) =
  mxy.modelBounds.minx = 100000
  mxy.modelBounds.maxx = -100000
  mxy.modelBounds.miny = 100000
  mxy.modelBounds.maxy = -100000

  mxy.scale.x = 0
  mxy.scale.y = 0

  mxy.poly = @[]

  for point in mxy.model.items():
    mxy.modelBounds.minx = min(point.x, mxy.modelBounds.minx)
    mxy.modelBounds.miny = min(point.y, mxy.modelBounds.miny)
    mxy.modelBounds.maxx = max(point.x, mxy.modelBounds.maxx)
    mxy.modelBounds.maxy = max(point.y, mxy.modelBounds.maxy)

  mxy.scale.x = (mxy.bounds.width - mxy.boundary * 2) / (mxy.modelBounds.maxx - mxy.modelBounds.minx)
  mxy.scale.y = (mxy.bounds.height - mxy.boundary * 2) / (mxy.modelBounds.maxy - mxy.modelBounds.miny)

  for point in mxy.model.items():
    mxy.poly.add(  mxy.boundary + (Coord(point.x.float32) - mxy.modelBounds.minx) * mxy.scale.x)
    mxy.poly.add(-(mxy.boundary + (Coord(point.y.float32) - mxy.modelBounds.miny) * mxy.scale.y) + Coord(mxy.bounds.height))

method init(mxy: PlotXY, w: Window, r: Rect) =
  procCall mxy.Control.init(w, r)
  mxy.backgroundColor = whiteColor()
  mxy.boundary = 50.0
  mxy.gridstep = 15.0
  mxy.dotSize = 4
  mxy.highlightedPoint = -1
  mxy.drawMedian = false

proc newPlotXY*(w: Window, r: Rect, model: ModelXYColor[float64]): PlotXY =
  result.new()
  result.model = model
  result.init(w, r)

method draw*(mxy: PlotXY, r: Rect) =
  procCall mxy.View.draw(r)

  updateModel(mxy)

  template gfxCtx: untyped = mxy.window.gfxCtx

  ## Draw grid
  gfxCtx.strokeColor = newGrayColor(0.7)
  gfxCtx.strokeWidth = 1

  for i in 0..mxy.gridstep.int:
    let
      pStart = newPoint(mxy.boundary, r.size.height - mxy.boundary - i.float32 * (r.size.height - mxy.boundary * 2) / mxy.gridstep)
      pEnd = newPoint(r.size.width - mxy.boundary, r.size.height - mxy.boundary - i.float32 * (r.size.height - mxy.boundary * 2) / mxy.gridstep)
    gfxCtx.drawLine(pStart, pEnd)

  for i in 0..mxy.gridstep.int:
    let
      pStart = newPoint(mxy.boundary + i.float32 * (r.size.width - mxy.boundary * 2) / mxy.gridstep, mxy.boundary)
      pEnd = newPoint(mxy.boundary + i.float32 * (r.size.width - mxy.boundary * 2) / mxy.gridstep, r.size.height - mxy.boundary)
    gfxCtx.drawLine(pStart, pEnd)

  ## Draw graph
  gfxCtx.fillColor = blackColor()
  gfxCtx.strokeColor = blackColor()
  gfxCtx.strokeWidth = 2

  if mxy.model.len() > 0:
    if mxy.drawMedian:
      gfxCtx.strokeColor = newColor(0.0, 1.0, 0.0)
      gfxCtx.drawLine(newPoint(mxy.poly[0], mxy.poly[1]), newPoint(mxy.poly[mxy.poly.len() - 2], mxy.poly[mxy.poly.len() - 1]))

    gfxCtx.strokeColor = blackColor()
    for i in countup(0, mxy.poly.len()-3, 2):
      gfxCtx.drawLine(
        newPoint(mxy.poly[i], mxy.poly[i+1]),
        newPoint(mxy.poly[i+2], mxy.poly[i+3])
      )
    for i in countup(0, mxy.poly.len()-3, 2):
      gfxCtx.strokeColor = mxy.model[(i/2).int].color
      gfxCtx.fillColor = gfxCtx.strokeColor

      if mxy.highlightedPoint != -1:
        if i == mxy.highlightedPoint or i == mxy.highlightedPoint + 1:
          gfxCtx.drawEllipseInRect(newRect(mxy.poly[i] - 6, mxy.poly[i+1] - 6, 12, 12))
      gfxCtx.drawEllipseInRect(newRect(mxy.poly[i] - mxy.dotSize.Coord, mxy.poly[i+1] - mxy.dotSize.Coord, mxy.dotSize.Coord * 2, mxy.dotSize.Coord * 2))
    gfxCtx.drawEllipseInRect(newRect(mxy.poly[^2] - mxy.dotSize.Coord, mxy.poly[^1] - mxy.dotSize.Coord, mxy.dotSize.Coord * 2, mxy.dotSize.Coord * 2))

  gfxCtx.fillColor = blackColor()
  gfxCtx.strokeColor = blackColor()
  let font = systemFont(gfxCtx.fontCtx)

  ## Draw title
  var pt = centerInRect(font.sizeOfString(mxy.title), newRect(0.0, 0.0, r.size.width, mxy.boundary))
  gfxCtx.drawText(font, pt, mxy.title)

  for i in 0..mxy.gridstep.int:
    let pt = newPoint(2, r.size.height - mxy.boundary - i.float32 * (r.size.height - mxy.boundary * 2) / mxy.gridstep)
    let stepValue = (mxy.modelBounds.maxy - mxy.modelBounds.miny) / mxy.gridstep * i.float32 + mxy.modelBounds.miny
    gfxCtx.drawText(font, pt, $stepValue.int)

  for i in 0..mxy.gridstep.int:
    pt = newPoint(mxy.boundary + i.float32 * (r.size.width - mxy.boundary * 2) / mxy.gridstep, r.size.height - mxy.boundary)
    let stepValue = (mxy.modelBounds.maxx - mxy.modelBounds.minx) / mxy.gridstep * i.float32 + mxy.modelBounds.minx
    gfxCtx.drawText(font, pt, $stepValue.int)

  ## Draw axes labels
  pt = newPoint(mxy.boundary / 2, mxy.boundary / 2)
  gfxCtx.drawText(font, pt, mxy.labelY)

  if mxy.highlightedPoint > -1:
    let index: int = (mxy.highlightedPoint.float).int
    let x = mxy.model[(index / 2).int].x
    let y = mxy.model[(index / 2).int].y
    gfxCtx.drawText(font, newPoint(mxy.poly[index], mxy.poly[index+1] - 20.0), "($#, $#)" % [$x, $y])

  pt = newPoint(r.size.width - mxy.boundary * 2, r.size.height - mxy.boundary / 1.5)
  gfxCtx.drawText(font, pt, mxy.labelX)

method onMouseDown(mxy: PlotXY, e: var Event): bool {.base.} =
  let pos = e.localPosition
  if pos.x < mxy.boundary or pos.x > mxy.bounds.width - mxy.boundary:
    return true
  if pos.y < mxy.boundary or pos.y > mxy.bounds.height - mxy.boundary:
    return true

  let xpart = ((pos.x - mxy.boundary) / (mxy.bounds.width - 2 * mxy.boundary))
  let ypart = (pos.y / (mxy.bounds.height - 2 * mxy.boundary))

  var hp: Point = newPoint(0.0, 0.0)
  hp.x = xpart * (mxy.modelBounds.maxx - mxy.modelBounds.minx)
  hp.y = ypart * (mxy.modelBounds.maxy - mxy.modelBounds.miny)

  for i, v in mxy.model.pairs():
    if v.x > hp.x:
      if hp.x - mxy.model[i-1].x < mxy.model[i].x - hp.x:
        mxy.highlightedPoint = (i - 1) * 2
      else:
        mxy.highlightedPoint = i * 2
      break

  mxy.setNeedsDisplay()
  return true

method onMouseUp(mxy: PlotXY, e: var Event): bool {.base.} =
  mxy.highlightedPoint = -1
  mxy.setNeedsDisplay()
  return true

method onTouchEv*(t: PlotXY, e: var Event): bool =
  case e.buttonState
  of bsDown: onMouseDown(t, e)
  of bsUp: onMouseUp(t, e)
  of bsUnknown: false


# nim r --threads:on nimxplot
when isMainModule:
  import nimx/[window, layout]
  # import nimxplot

  runApplication:
    newFullscreenWindow().makeLayout:
      - PlotXY:
        leading == super + 10
        trailing == super - 10
        top == super + 10
        bottom == super - 10
        title: "Dependency of Y from X"
        labelY: "Y"
        labelX: "X"
        model: @[
          (x: 0.0, y: 0.0, color: newColor(0, 0, 0)),
          (x: 10.0, y: 10.0, color: newColor(1, 0, 0)),
          (x: 20.0, y: 10.0, color: newColor(0, 1, 0)),
          (x: 60.0, y: 300.0, color: newColor(0, 0, 1)),
          (x: 100.0, y: 200.0, color: newColor(1, 1, 0))
        ]
