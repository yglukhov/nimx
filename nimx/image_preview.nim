import math

import nimx/font
import nimx/image
import nimx/button
import nimx/view
import nimx/event
import nimx/panel_view
import nimx/context
import nimx/types

import nimx / meta_extensions / [ property_desc, visitors_gen, serializers_gen ]


const titleSize = 20.0
const bottomSize = 30.0
const maxSize = 768.0
const minSize = 128.0

type ImagePreview* = ref object of PanelView
    image*: Image
    title*: string
    contentView* {.deprecated.}: View
    imgScale*: float
    imageRect*: Rect

#todo: fix this, make image setter
method init*(v: ImagePreview, gfx: GraphicsContext, r: Rect) =
    let maxLen = max(v.image.size.width, v.image.size.height)
    var scale = 1.0
    if maxLen > maxSize:
        scale = maxSize / maxLen

    var content = newSize(v.image.size.width * scale, v.image.size.height * scale)
    if v.image.size.width < minSize:
        content.width = minSize
    if v.image.size.height < minSize:
        content.height = minSize

    var viewRect: Rect
    viewRect.size.width = content.width + 2.0
    viewRect.size.height = content.height + titleSize + 1.0 + 30.0

    procCall v.PanelView.init(gfx, viewRect)
    v.backgroundColor = newColor(0.2, 0.2, 0.2, 1.0)
    v.title = "Image Preview"
    v.imgScale = scale

    let closeBttn = newButton(v, gfx, newPoint(viewRect.width - 16.0 - 1.0, 1.0), newSize(16, 16), "X")
    closeBttn.autoresizingMask = {afFlexibleMinX, afFlexibleMaxY}
    closeBttn.onAction do():
        v.removeFromSuperview()

proc newImagePreview*(gfx: GraphicsContext, r: Rect, img: Image): ImagePreview =
    result.new()
    result.image = img
    result.init(gfx, r)

method draw*(v: ImagePreview, r: Rect) =
    procCall v.PanelView.draw(r)
    template gfx: untyped = v.gfx
    template fontCtx: untyped = gfx.fontCtx
    let f = systemFontOfSize(fontCtx, 14.0)
    var titleRect: Rect
    titleRect.size.width = r.width
    titleRect.size.height = titleSize
    gfx.fillColor = newColor(0.2, 0.2, 0.2)
    gfx.drawRect(titleRect)

    var contentRect: Rect
    contentRect.origin.x = 1.0
    contentRect.origin.y = titleSize
    contentRect.size.width = r.width - 2.0
    contentRect.size.height = r.height - titleSize - bottomSize - 1.0
    gfx.fillColor = newColor(0.5, 0.5, 0.5)
    gfx.drawRect(contentRect)

    gfx.fillColor = newColor(0.9, 0.9, 0.9)
    gfx.drawText(f, newPoint(5, 1), v.title)

    # Draw Image
    v.imageRect.origin.x = 1.0
    v.imageRect.origin.y = titleSize
    v.imageRect.size.width = v.image.size.width * v.imgScale
    v.imageRect.size.height = v.image.size.height * v.imgScale
    gfx.drawImage(v.image, v.imageRect)

    # Draw Info
    let sizeInfo = "Size: " & $v.image.size.width & " x " & $v.image.size.height
    gfx.drawText(f, newPoint(5, r.height - bottomSize / 2.0), sizeInfo)

    var pathInfo = "Path: nil"
    if v.image.filePath.len != 0:
        pathInfo = "Path: " & $v.image.filePath
    gfx.drawText(f, newPoint(5, r.height - bottomSize), pathInfo)

# method onTouchEv*(v: ImagePreview, e: var Event) : bool =
#     discard procCall v.PanelView.onTouchEv(e)
    # if  e.localPosition
#     result = true

# method onScroll*(v: ImagePreview, e: var Event): bool =
#     v.imgScale += (e.offset.y / 300.0)
#     result = true

proc popupAtPoint*(ip: ImagePreview, v: View, p: Point) =
    ip.removeFromSuperview()
    var origin: Point
    origin = v.convertPointToWindow(p)
    if origin.x > v.window.bounds.size.width / 2.0:
        origin.x -= ip.image.size.width * ip.imgScale
    else:
        origin.x += 50.0
    origin.y = 35.0
    ip.setFrameOrigin(origin)
    v.window.addSubview(ip)

ImagePreview.properties:
    image
    title
    imgScale
    imageRect

registerClass(ImagePreview)
genVisitorCodeForView(ImagePreview)
genSerializeCodeForView(ImagePreview)