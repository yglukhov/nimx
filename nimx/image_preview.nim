import std/math
import ./[font, image, button, view, event, context, types, layout, app, view_event_handling, clip_view]

const titleSize = 20.0
const bottomSize = 30.0
const maxSize = 768.0
const minSize = 512.0

type ImagePreview* = ref object of View
  image*: Image
  imageRect: Rect
  scaleOverride: float
  positionOverride: Point
  draggingStart: Point

method init*(v: ImagePreview) =
  procCall v.View.init()
  v.backgroundColor = newColor(0.2, 0.2, 0.2, 1.0)
  v.scaleOverride = 1.0

method draw*(v: ImagePreview, r: Rect) =
  procCall v.View.draw(r)
  if v.image.isNil:
    return

  let c = currentContext()
  let f = systemFontOfSize(14.0)

  var titleRect: Rect
  titleRect.size.width = r.width
  titleRect.size.height = titleSize

  var contentRect: Rect
  contentRect.origin.x = 1.0
  contentRect.origin.y = titleSize
  contentRect.size.width = r.width - 2.0
  contentRect.size.height = r.height - titleSize - bottomSize - 1.0

  var bottomRect: Rect
  bottomRect.origin.x = 1
  bottomRect.origin.y = contentRect.size.height + contentRect.origin.y + 1.0
  bottomRect.size.width = contentRect.size.width
  bottomRect.size.height = bottomSize

  c.fillColor = newColor(0.5, 0.5, 0.5)
  c.drawRect(contentRect)

  var maxSide = max(v.image.size.width, v.image.size.height)
  var scale = 1.0
  if maxSide > maxSize:
    scale = maxSize / maxSide
  if maxSide < minSize:
    scale =  minSize / maxSide
  v.imageRect.size.width = v.image.size.width * scale * v.scaleOverride
  v.imageRect.size.height = v.image.size.height * scale * v.scaleOverride
  v.imageRect.origin.x = (v.frame.size.width - v.imageRect.size.width) * 0.5 + v.positionOverride.x
  v.imageRect.origin.y = titleSize + (v.frame.size.height - v.imageRect.size.height) * 0.5 + v.positionOverride.y
  c.drawImage(v.image, v.imageRect)

  c.fillColor = newColor(0.2, 0.2, 0.2)
  c.drawRect(titleRect)
  c.drawRect(bottomRect)
  c.fillColor = newColor(0.9, 0.9, 0.9)
  c.drawText(f, newPoint(5, 1), "Image preview")

  # Draw Info
  let sizeInfo = "Size: " & $v.image.size.width & " x " & $v.image.size.height
  c.drawText(f, newPoint(5, r.height - bottomSize / 2.0), sizeInfo)

  var pathInfo = "Path: nil"
  if v.image.filePath.len != 0:
    pathInfo = "Path: " & $v.image.filePath
  c.drawText(f, newPoint(5, r.height - bottomSize), pathInfo)
  # c.drawText(f, newPoint(5, r.height - bottomSize), pathInfo)

method onTouchEv*(v: ImagePreview, e: var Event) : bool =
  discard procCall v.View.onTouchEv(e)
  if e.buttonState == bsDown:
    v.draggingStart = e.localPosition - v.positionOverride
  elif e.buttonState == bsUp:
    discard
  else:
    v.positionOverride = e.localPosition - v.draggingStart
  result = true

method onScroll*(v: ImagePreview, e: var Event): bool =
  v.scaleOverride = clamp(v.scaleOverride + (e.offset.y / 300.0), 0.1, 10.0)
  result = true

proc addOriginConstraints(w: Window, v: View, desiredOrigin: Point) =
  let w = mainApplication().keyWindow
  var wp = desiredOrigin
  v.addConstraint(modifyStrength(selfPHS.x == wp.x, MEDIUM))
  v.addConstraint(modifyStrength(selfPHS.y == wp.y, MEDIUM))
  v.addConstraint(selfPHS.leading >= w.layout.vars.leading)
  v.addConstraint(selfPHS.trailing <= w.layout.vars.trailing)
  v.addConstraint(selfPHS.top >= w.layout.vars.top)
  v.addConstraint(selfPHS.bottom <= w.layout.vars.bottom)

proc popupAtPoint*(v: ImagePreview, p: Point) =
  if v.image.isNil:
    return

  var parent = new(ClipView)
  let w = mainApplication().keyWindow
  w.addOriginConstraints(parent, p)
  var targetW = max(min(v.image.size.width, maxSize), minSize)
  var targetH = max(min(v.image.size.height, maxSize), minSize)
  parent.makeLayout:
    width == targetW
    height == targetH
  v.makeLayout:
    frame == super
    - Button as close:
      top == super
      trailing == super
      width == 20
      height == 20
      title:"X"
      onAction:
        parent.removeFromSuperview()
  parent.addSubview(v)
  w.addSubview(parent)

proc popupAtCenterOfWindow*(v: ImagePreview) =
  let w = mainApplication().keyWindow
  var targetW = max(min(v.image.size.width, maxSize), minSize)
  var targetH = max(min(v.image.size.height, maxSize), minSize)
  var x = w.frame.width - min(targetW, w.frame.size.width - 50)
  var y = w.frame.height - min(targetH, w.frame.size.height - 50)
  v.popupAtPoint(newPoint(x * 0.5, y * 0.5))
