import control
import context
import image
import types
import system_logger
import event
import font
import app
import view_event_handling
import view_event_handling_new
import composition
import property_visitor
import serializers
import resource

export control

const selectionColor = newColor(0.40, 0.59, 0.95)

type ButtonStyle* = enum
    bsRegular
    bsCheckbox
    bsRadiobox
    bsImage
    bsNinePartImage

type ButtonBehavior = enum
    bbMomentaryLight
    bbToggle

type Button* = ref object of Control
    title*: string
    image*: Image
    imageMarginLeft*: Coord
    imageMarginRight*: Coord
    imageMarginTop*: Coord
    imageMarginBottom*: Coord
    state*: ButtonState
    value*: int8
    enabled*: bool
    hasBezel*: bool
    style*: ButtonStyle
    behavior*: ButtonBehavior

proc newButton*(r: Rect): Button =
    result.new()
    result.init(r)

proc newButton*(parent: View = nil, position: Point = newPoint(0, 0), size: Size = newSize(100, 20), title: string = "Button"): Button =
    result = newButton(newRect(position.x, position.y, size.width, size.height))
    result.title = title
    if not isNil(parent):
        parent.addSubview(result)

proc newCheckbox*(r: Rect): Button =
    result = newButton(r)
    result.style = bsCheckbox
    result.behavior = bbToggle

proc newRadiobox*(r: Rect): Button =
    result = newButton(r)
    result.style = bsRadiobox
    result.behavior = bbToggle

proc newImageButton*(r: Rect): Button =
    result = newButton(r)
    result.style = bsImage

proc newImageButton*(parent: View = nil, position: Point = newPoint(0, 0), size: Size = newSize(100, 20), image: Image = nil): Button =
    result = newImageButton(newRect(position.x, position.y, size.width, size.height))
    result.image = image
    if not isNil(parent):
        parent.addSubview(result)

method init(b: Button, frame: Rect) =
    procCall b.Control.init(frame)
    b.state = bsUp
    b.enabled = true
    b.backgroundColor = whiteColor()
    b.hasBezel = true
    b.imageMarginLeft = 2
    b.imageMarginRight = 2
    b.imageMarginTop = 2
    b.imageMarginBottom = 2

proc drawTitle(b: Button, xOffset: Coord) =
    if b.title != nil:
        let c = currentContext()
        c.fillColor = if b.state == bsDown and b.style == bsRegular:
                whiteColor()
            else:
                blackColor()

        let font = systemFont()
        var titleRect = b.bounds
        var pt = centerInRect(font.sizeOfString(b.title), titleRect)
        if pt.x < xOffset: pt.x = xOffset
        c.drawText(font, pt, b.title)

var regularButtonComposition = newComposition """
uniform vec4 uStrokeColor;
uniform vec4 uFillColorStart;
uniform vec4 uFillColorEnd;
uniform float uShadowOffset;
float radius = 5.0;

void compose() {
    drawInitialShape(sdRoundedRect(insetRect(bounds, 1.0), radius), uStrokeColor);
    vec4 fc = gradient(smoothstep(bounds.y, bounds.y + bounds.w, vPos.y),
        uFillColorStart,
        uFillColorEnd);
    drawShape(sdRoundedRect(insetRect(bounds, 2.0) + vec4(0.0, uShadowOffset, 0.0, uShadowOffset), radius - 1.0), fc);
}
"""

proc drawRegularStyle(b: Button, r: Rect) {.inline.} =
    if b.hasBezel:
        regularButtonComposition.draw r:
            if b.state == bsUp:
                setUniform("uStrokeColor", newGrayColor(0.78))
                setUniform("uFillColorStart", if b.enabled: b.backgroundColor else: grayColor())
                setUniform("uFillColorEnd", if b.enabled: b.backgroundColor else: grayColor())
                setUniform("uShadowOffset", -0.5'f32)
            else:
                setUniform("uStrokeColor", newColor(0.18, 0.50, 0.98))
                setUniform("uFillColorStart", newColor(0.31, 0.60, 0.98))
                setUniform("uFillColorEnd", newColor(0.09, 0.42, 0.88))
                setUniform("uShadowOffset", 0.0'f32)
    b.drawTitle(0)

var checkButtonComposition = newComposition """
uniform vec4 uStrokeColor;
uniform vec4 uFillColor;

float radius = 4.0;

void compose() {
    drawInitialShape(sdRoundedRect(insetRect(bounds, 1.0), radius), uStrokeColor);
    drawShape(sdRoundedRect(insetRect(bounds, 2.0), radius - 1.0), uFillColor);
}
"""

proc drawCheckboxStyle(b: Button, r: Rect) =
    let
        size = b.bounds.height
        bezelRect = newRect(0, 0, size, size)
        c = currentContext()

    if b.value != 0:
        checkButtonComposition.draw bezelRect:
            setUniform("uStrokeColor", selectionColor)
            setUniform("uFillColor", selectionColor)
            setUniform("uRadius", 4.0)

        c.strokeWidth = 2.0

        c.fillColor = newGrayColor(0.7)
        c.strokeColor = newGrayColor(0.7)
        c.drawLine(newPoint(size / 4.0, size * 1.0 / 2.0 + 1.0), newPoint(size / 4.0 * 2.0, size * 1.0 / 2.0 + size / 5.0 - c.strokeWidth / 2.0 + 1.0))
        c.drawLine(newPoint(size / 4.0 * 2.0 - c.strokeWidth / 2.0, size * 1.0 / 2.0 + size / 5.0 + 1.0), newPoint(size / 4.0 * 3.0 - c.strokeWidth / 2.0, size / 4.0 + 1.0))

        c.fillColor = whiteColor()
        c.strokeColor = whiteColor()
        c.drawLine(newPoint(size / 4.0, size * 1.0 / 2.0), newPoint(size / 4.0 * 2.0, size * 1.0 / 2.0 + size / 5.0 - c.strokeWidth / 2.0))
        c.drawLine(newPoint(size / 4.0 * 2.0 - c.strokeWidth / 2.0, size * 1.0 / 2.0 + size / 5.0), newPoint(size / 4.0 * 3.0 - c.strokeWidth / 2.0, size / 4.0))
    else:
        checkButtonComposition.draw bezelRect:
            setUniform("uStrokeColor", newGrayColor(0.78))
            setUniform("uFillColor", whiteColor())
            setUniform("uRadius", 4.0)

    b.drawTitle(bezelRect.width + 1)

var radioButtonComposition = newComposition """
uniform vec4 uStrokeColor;
uniform vec4 uFillColor;
uniform float uRadioValue;
uniform float uStrokeWidth;

void compose() {
    vec4 outer = vec4(bounds.xy + 1.0, bounds.zw - 2.0);
    drawInitialShape(sdRoundedRect(outer, bounds.w / 2.0 - 1.0), uStrokeColor);
    vec4 inner = insetRect(outer, uRadioValue);
    drawShape(sdEllipseInRect(vec4(inner.x, inner.y + 1.0, inner.zw)), vec4(0.7));
    drawShape(sdEllipseInRect(inner), vec4(1.0));
}
"""

proc drawRadioboxStyle(b: Button, r: Rect) =
    let bezelRect = newRect(0, 0, b.bounds.height, b.bounds.height)

    # Selected
    if b.value != 0:
        radioButtonComposition.draw bezelRect:
            setUniform("uStrokeColor", selectionColor)
            setUniform("uFillColor", selectionColor)
            setUniform("uRadioValue", bezelRect.height * 0.3)
            setUniform("uStrokeWidth", 0.0)
    else:
        radioButtonComposition.draw bezelRect:
            setUniform("uStrokeColor", newGrayColor(0.78))
            setUniform("uFillColor", whiteColor())
            setUniform("uRadioValue", 1.0)
            setUniform("uStrokeWidth", 0.0)

    b.drawTitle(bezelRect.width + 1)

proc drawImageStyle(b: Button, r: Rect) =
    if b.hasBezel:
        regularButtonComposition.draw r:
            if b.state == bsUp:
                setUniform("uStrokeColor", newGrayColor(0.78))
                setUniform("uFillColorStart", if b.enabled: b.backgroundColor else: grayColor())
                setUniform("uFillColorEnd", if b.enabled: b.backgroundColor else: grayColor())
            else:
                setUniform("uStrokeColor", newColor(0.18, 0.50, 0.98))
                setUniform("uFillColorStart", newColor(0.31, 0.60, 0.98))
                setUniform("uFillColorEnd", newColor(0.09, 0.42, 0.88))
    let c = currentContext()
    c.drawImage(b.image, newRect(r.x + b.imageMarginLeft, r.y + b.imageMarginTop,
        r.width - b.imageMarginLeft - b.imageMarginRight, r.height - b.imageMarginTop - b.imageMarginBottom))

proc drawNinePartImageStyle(b: Button, r: Rect) =
    let c = currentContext()
    c.drawNinePartImage(b.image, b.bounds, b.imageMarginLeft, b.imageMarginTop, b.imageMarginRight, b.imageMarginBottom)

method draw(b: Button, r: Rect) =
    case b.style
    of bsRadiobox:
        b.drawRadioboxStyle(r)
    of bsCheckbox:
        b.drawCheckboxStyle(r)
    of bsImage:
        b.drawImageStyle(r)
    of bsNinePartImage:
        b.drawNinePartImageStyle(r)
    else:
        b.drawRegularStyle(r)

proc setState*(b: Button, s: ButtonState) =
    if b.state != s:
        b.state = s
        b.setNeedsDisplay()

proc enable*(b: Button) =
    b.enabled = true

proc disable*(b: Button) =
    b.enabled = false

method sendAction*(b: Button, e: Event) =
    if b.enabled:
        proccall Control(b).sendAction(e)

template boolValue*(b: Button): bool = bool(b.value)

template toggleValue(v: int8): int8 =
    if v == 0:
        1
    else:
        0

method name(b: Button): string =
    result = "Button"

method onTouchEv(b: Button, e: var Event): bool =
    discard procCall b.View.onTouchEv(e)
    case e.buttonState
    of bsDown:
        b.setState(bsDown)
        if b.behavior == bbMomentaryLight:
            b.value = 1
    of bsUnknown:
        if e.localPosition.inRect(b.bounds):
            b.setState(bsDown)
        else:
            b.setState(bsUp)
    of bsUp:
        b.setState(bsUp)
        if b.behavior == bbMomentaryLight:
            b.value = 0
        if e.localPosition.inRect(b.bounds):
            if b.behavior == bbToggle:
                b.value = toggleValue(b.value)
            b.sendAction(e)
    result = true

method visitProperties*(v: Button, pv: var PropertyVisitor) =
    procCall v.Control.visitProperties(pv)
    pv.visitProperty("title", v.title)
    pv.visitProperty("state", v.state)
    pv.visitProperty("style", v.style)
    pv.visitProperty("enabled", v.enabled)
    pv.visitProperty("hasBezel", v.hasBezel)
    pv.visitProperty("behavior", v.behavior)
    pv.visitProperty("image", v.image)
    pv.visitProperty("marginLeft", v.imageMarginLeft)
    pv.visitProperty("marginRight", v.imageMarginRight)
    pv.visitProperty("marginTop", v.imageMarginTop)
    pv.visitProperty("marginBottom", v.imageMarginBottom)

method serializeFields*(v: Button, s: Serializer) =
    procCall v.Control.serializeFields(s)
    s.serialize("title", v.title)
    s.serialize("state", v.state)
    s.serialize("style", v.style)
    s.serialize("enabled", v.enabled)
    s.serialize("hasBezel", v.hasBezel)
    s.serialize("behavior", v.behavior)
    let imagePath = if v.image.isNil: nil else: v.image.filePath
    s.serialize("image", imagePath)
    s.serialize("marginLeft", v.imageMarginLeft)
    s.serialize("marginRight", v.imageMarginRight)
    s.serialize("marginTop", v.imageMarginTop)
    s.serialize("marginBottom", v.imageMarginBottom)


method deserializeFields*(v: Button, s: Deserializer) =
    procCall v.Control.deserializeFields(s)
    s.deserialize("title", v.title)
    s.deserialize("state", v.state)
    s.deserialize("style", v.style)
    s.deserialize("enabled", v.enabled)
    s.deserialize("hasBezel", v.hasBezel)
    s.deserialize("behavior", v.behavior)
    var imgName : string
    s.deserialize("image", imgName)
    if not imgName.isNil:
        v.image = imageWithResource(imgName)
    s.deserialize("marginLeft", v.imageMarginLeft)
    s.deserialize("marginRight", v.imageMarginRight)
    s.deserialize("marginTop", v.imageMarginTop)
    s.deserialize("marginBottom", v.imageMarginBottom)

registerClass(Button)
