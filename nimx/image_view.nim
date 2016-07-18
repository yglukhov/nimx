import nimx.context
import nimx.image
import nimx.types
import nimx.view
import nimx.property_visitor
import nimx.serializers
import nimx.resource

type
    ImageFillRule* {.pure.} = enum
        ## Defines how image is drawn inside view
        NoFill    ## Image is drawn from top-left corner with its size
        Stretch   ## Image is stretched to view size
        Tile      ## Image tiles all view
        FitWidth  ## Image fits view's width
        FitHeight ## Image fits view's height
        NinePartImage

    ImageView* = ref object of View
        ## Image view is a view for drawing static images
        ## with certain view filling rules
        image:   Image
        fillRule: ImageFillRule
        imageMarginLeft*: Coord
        imageMarginRight*: Coord
        imageMarginTop*: Coord
        imageMarginBottom*: Coord

proc newImageView*(r: Rect, image: Image = nil, fillRule = ImageFillRule.NoFill): ImageView =
    result.new
    result.image = image
    result.fillRule = fillRule
    result.init(r)

method init*(v: ImageView, r: Rect) =
    procCall v.View.init(r)
    v.backgroundColor = newColor(1.0, 1.0, 1.0, 1.0)

proc image*(v: ImageView): Image = v.image
proc `image=`*(v: ImageView, image: Image) =
    v.image = image
    v.setNeedsDisplay()

proc fillRule*(v: ImageView): ImageFillRule = v.fillRule
proc `fillRule=`*(v: ImageView, fillRule: ImageFillRule) =
    v.fillRule = fillRule
    v.setNeedsDisplay()

method clipType*(v: ImageView): ClipType = ctDefaultClip

method draw(v: ImageView, r: Rect) =
    procCall v.View.draw(r)
    let c = currentContext()

    if v.image.isNil():
        c.drawRect(r)
        c.drawLine(newPoint(r.x, r.y), newPoint(r.x + r.width, r.y + r.height))
        c.drawLine(newPoint(r.x, r.y + r.height), newPoint(r.x + r.width, r.y))
    else:
        case v.fillRule
        of ImageFillRule.NoFill:
            c.drawImage(v.image, newRect(r.x, r.y, v.image.size.width, v.image.size.height))
        of ImageFillRule.Stretch:
            c.drawImage(v.image, r)
        of ImageFillRule.Tile:
            let cols = r.width.int div v.image.size.width.int + 1
            let rows = r.height.int div v.image.size.height.int + 1
            for col in 0 ..< cols:
                for row in 0..< rows:
                    let imageRect = newRect(col.Coord * v.image.size.width, row.Coord * v.image.size.height, v.image.size.width, v.image.size.height)
                    c.drawImage(v.image, imageRect)
        of ImageFillRule.FitWidth:
            let
                stretchRatio = r.width / v.image.size.width
                newWidth = r.width
                newHeight = v.image.size.height * stretchRatio
                newX = 0.Coord
                newY = if newHeight > r.height: 0.Coord else: r.height / 2 - newHeight / 2
            c.drawImage(v.image, newRect(newX, newY, newWidth, newHeight))
        of ImageFillRule.FitHeight:
            let
                stretchRatio = r.height / v.image.size.height
                newHeight = r.height
                newWidth = v.image.size.width * stretchRatio
                newY = 0.Coord
                newX = if newWidth > r.width: 0.Coord else: r.width / 2 - newWidth / 2
            c.drawImage(v.image, newRect(newX, newY, newWidth, newHeight))
        of ImageFillRule.NinePartImage:
            c.drawNinePartImage(v.image, v.bounds, v.imageMarginLeft, v.imageMarginTop, v.imageMarginRight, v.imageMarginBottom)

method visitProperties*(v: ImageView, pv: var PropertyVisitor) =
    procCall v.View.visitProperties(pv)
    pv.visitProperty("image", v.image)
    pv.visitProperty("fillRule", v.fillRule)
    pv.visitProperty("marginLeft", v.imageMarginLeft)
    pv.visitProperty("marginRight", v.imageMarginRight)
    pv.visitProperty("marginTop", v.imageMarginTop)
    pv.visitProperty("marginBottom", v.imageMarginBottom)

method serializeFields*(v: ImageView, s: Serializer) =
    procCall v.View.serializeFields(s)
    s.serialize("image", resourceNameForPath(v.image.filePath))
    s.serialize("fillRule", v.fillRule)
    s.serialize("marginLeft", v.imageMarginLeft)
    s.serialize("marginRight", v.imageMarginRight)
    s.serialize("marginTop", v.imageMarginTop)
    s.serialize("marginBottom", v.imageMarginBottom)

method deserializeFields*(v: ImageView, s: Deserializer) =
    procCall v.View.deserializeFields(s)
    s.deserialize("fillRule", v.fillRule)
    var imgName : string
    s.deserialize("image", imgName)
    if not imgName.isNil:
        v.image = imageWithResource(imgName)
    s.deserialize("marginLeft", v.imageMarginLeft)
    s.deserialize("marginRight", v.imageMarginRight)
    s.deserialize("marginTop", v.imageMarginTop)
    s.deserialize("marginBottom", v.imageMarginBottom)

registerClass(ImageView)
