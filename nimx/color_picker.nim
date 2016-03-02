import math

import view
export view

import context
import composition
import event
import types
import portable_gl
import popup_button
import text_field

const margin = 6

type
    ColorPickerPalette* {.pure.} = enum
        HSV

    ColorPickerCircle* = ref object of View
        radius: Coord
        currentColor: tuple[h: float, s: float, v: float]
        palette: ColorPickerPalette

    ColorPickerView* = ref object of View
        palette: ColorPickerPalette
        colorHistory: seq[Color]

        circle: ColorPickerCircle
        paletteChooser: PopupButton
        chosenColorView: View

        # Graphics metrics
        rightMargin: Coord

# ColorPickerCircle

proc newColorPickerCircle(defaultPalette: ColorPickerPalette, radius: Coord): ColorPickerCircle =
    result.new
    result.radius = radius
    result.palette = defaultPalette
    result.currentColor = (0.0, 0.0, 0.0)

proc radius*(cpc: ColorPickerCircle): Coord = cpc.radius
    ## Get Color Picker Circle Radius

proc hsvToRGB(h: float, s: float, v: float): Color =
    ## Helper proc for convertin color from HSV to RGV format
    if (s == 0):
        return newColor(v, v, v)
    else:
        var H = h * 6
        if H == 6:
            H = 0
        var I = floor(H)
        var c1 = v * (1.0 - s)
        var c2 = v * (1.0 - s * (H - I))
        var c3 = v * (1.0 - s * (1.0 - (H - I)))

        if I == 0:
            return newColor(v, c3, c1)
        elif I == 1:
            return newColor(c2, v, c1)
        elif I == 2:
            return newColor(c1, v, c3)
        elif I == 3:
            return newColor(c1, c2, v)
        elif I == 4:
            return newColor(c3, c1, v)
        else:
            return newColor(v, c1, c2)

proc currentColor*(cpc: ColorPickerCircle): Color =
    ## Return current chosen color on circle
    return hsvToRGB(cpc.currentColor.h, cpc.currentColor.s, cpc.currentColor.v)

var hsvCircleComposition = newComposition """
    uniform float uHsvValue;
    uniform float uChosenH;

    vec4 cHsvCircle() {
        float r = bounds.z / 2.0;
        vec2 c = vec2(bounds.xy + (bounds.zw / 2.0));
        float h = (atan(vPos.y - c.y, c.x - vPos.x) / 3.1415 + 1.0) / 2.0;
        float s = distance(vPos, c) / r;
        float v = uHsvValue;
        return vec4(hsv2rgb(vec3(h, s, v)), 1.0);
    }

    void compose() {
        drawShape(sdEllipseInRect(bounds), cHsvCircle());
        drawShape(sdEllipseInRect(vec4(bounds.xy + bounds.z / 4.0, bounds.zw / 2.0)), vec4(0.0, 0.0, 0.0, 0.0));
    }
"""

proc drawHSVCircleComposition(c: GraphicsContext, r: Rect, hsvValue: float, chosenH: float) =
    hsvCircleComposition.draw r:
        setUniform("uHsvValue", hsvValue)
        setUniform("uChosenH", chosenH)

method draw*(cpc: ColorPickerCircle, r: Rect) =
    ## Custom palette drawing
    let c = currentContext()

    # Draw hsv circle
    c.fillColor = newGrayColor(0.0, 0.0)
    c.strokeColor = newGrayColor(0.0, 0.0)
    c.drawHSVCircleComposition(newRect(0, 0, cpc.radius * 2.0, cpc.radius * 2.0), 1.0, cpc.currentColor.h)

method onTouchEv*(cpc: ColorPickerCircle, e: var Event): bool =
    ## Choose color
    let radius = cpc.frame.width / 2.0
    let center = newPoint(cpc.frame.width / 2.0, cpc.frame.height / 2.0)

    let h = (arctan2(e.localPosition.y - center.y, center.x - e.localPosition.x) / 3.1415 + 1.0) / 2.0
    let v = 1.0
    let s = sqrt(pow(e.localPosition.x - center.x, 2) + pow(e.localPosition.y - center.y, 2)) / radius

    if s < 1.0 and s > 0.5:
        cpc.currentColor = (h, s, v)
        ColorPickerView(cpc.superview).chosenColorView.backgroundColor = hsvToRGB(cpc.currentColor.h, cpc.currentColor.s, cpc.currentColor.v)
        cpc.superview.setNeedsDisplay()

# ColorPickerView

proc newColorPickerView*(r: Rect, defaultPalette = ColorPickerPalette.HSV, backgroundColor: Color = newGrayColor(0.35, 0.6)): ColorPickerView =
    ## ColorPickerView constructor
    result.new
    result.init(r)
    result.palette = defaultPalette
    result.backgroundColor = backgroundColor

proc currentColor*(cpv: ColorPickerView): Color =
    ## Return current chosen color
    hsvToRGB(cpv.circle.currentColor.h, cpv.circle.currentColor.s, cpv.circle.currentColor.v)

method init*(cpv: ColorPickerView, r: Rect) =
    # Basic Properties Initialization
    procCall cpv.View.init(r)
    cpv.colorHistory = @[]
    cpv.rightMargin = r.width * 2.0 / 3.0

    # Color Picker Circle
    let rightSize = r.width - cpv.rightMargin
    cpv.circle = newColorPickerCircle(ColorPickerPalette.HSV, (rightSize - 2.0 * margin) / 2.0)
    cpv.circle.setFrameOrigin(newPoint(cpv.rightMargin + margin, margin))
    cpv.circle.setFrameSize(newSize(rightSize - margin, rightSize - margin))
    cpv.addSubview(cpv.circle)

    # Color Palette Popup Chooser
    let
        paletteSize = r.height - rightSize
        paletteHeight = 20.Coord

    cpv.paletteChooser = newPopupButton(
        cpv,
        newPoint(cpv.rightMargin + margin, rightSize + paletteSize / 2 - paletteHeight / 2),
        newSize(rightSize - margin * 2, paletteHeight),
        items = @["HSV"]
    )

    # Current Chosen Color Quad
    cpv.chosenColorView = newView(newRect(margin, margin, r.height / 4.0, r.height / 4.0))
    cpv.chosenColorView.backgroundColor = cpv.currentColor()
    cpv.addSubview(cpv.chosenColorView)

    let coff = r.height - (20 * 3 + margin * 4)

    let hLabel = newTextField(cpv, newPoint(margin, coff + margin), newSize(20, 20), "H:")
    let sLabel = newTextField(cpv, newPoint(margin, coff + margin * 2 + 20), newSize(20, 20), "S:")
    let vLabel = newTextField(cpv, newPoint(margin, coff + margin * 3 + 40), newSize(20, 20), "V:")

    # HSV Components Views
