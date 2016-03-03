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
import view_event_handling
import view_event_handling_new

const
    margin = 6

type
    ColorPickerPalette* {.pure.} = enum
        HSV

    ColorView* = ref object of View
        ## Color quad that reacts to outer world
        main: bool    ## Defines if view is main or from history

    ColorPickerCircle* = ref object of View
        radius: Coord
        currentColor: tuple[h: float, s: float, v: float]
        palette: ColorPickerPalette

    ColorPickerH* = ref object of View
        ## Hue tuning widget

    ColorPickerS* = ref object of View
        ## Saturation tuning widget

    ColorPickerV* = ref object of View
        ## Value tuning widget

    ColorPickerView* = ref object of View
        ## Complex Widget that allows to pick color using HSV palette
        palette:         ColorPickerPalette  ## Palette (RGB, HSV, HSL, etc.)
        colorHistory:    seq[ColorView]      ## History of chosen colors
        lastInHistory:   int                 ## Last item index added to history

        circle*:         ColorPickerCircle   ## Color picking circle
        paletteChooser:  PopupButton         ## Palette choser popup
        chosenColorView: View                ## Quad that shows current color

        cpH: ColorPickerH                    ## Hue tuning widget
        cpS: ColorPickerS                    ## Saturation tuning widget
        cpV: ColorPickerV                    ## Value tuning widget

        # Graphics metrics
        rightMargin:     Coord               ## Circle offset (layout-helper)

        # Callbacks
        onColorSelected*: proc(c: Color)

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

proc hsvToRgb(color: tuple[h: float, s: float, v: float]): Color =
    hsvToRgb(color.h, color.s, color.v)

# ColorPickerH

proc newColorPickerH(r: Rect): ColorPickerH =
    ## Hue picker constructor
    result.new
    result.init(r)

method init(cph: ColorPickerH, r: Rect) =
    procCall cph.View.init(r)

var cpHComposition = newComposition """
    uniform float uChosenH;

    vec4 cHQuad() {
        if (abs(uChosenH - vPos.x / bounds.z) < 0.003)
            return vec4(0.0, 0.0, 0.0, 1.0);
        else
            return vec4(hsv2rgb(vec3(vPos.x / bounds.z, 1.0, 1.0)), 1.0);
    }

    void compose() {
        drawShape(sdRect(bounds), cHQuad());
    }
"""

method draw(cph: ColorPickerH, r: Rect) =
    ## Drawing Hue picker
    let c = currentContext()
    let cc = ColorPickerView(cph.superview).circle.currentColor

    cpHComposition.draw r:
        setUniform("uChosenH", cc.h)

method onTouchEv(cph: ColorPickerH, e: var Event): bool =
    let cpv = ColorPickerView(cph.superView)

    if e.buttonState == bsUp:
        cpv.circle.currentColor.h = e.localPosition.x / cph.frame.width
        cpv.chosenColorView.backgroundColor = hsvToRGB(cpv.circle.currentColor)
        cpv.setNeedsDisplay()

    return true

# ColorPickerS

proc newColorPickerS(r: Rect): ColorPickerS =
    ## Saturation picker constructor
    result.new
    result.init(r)

method init(cps: ColorPickerS, r: Rect) =
    procCall cps.View.init(r)

var cpSComposition = newComposition """
    uniform float uHcps;
    uniform float uChosenS;

    vec4 cSQuad() {
        if (abs(uChosenS - vPos.x / bounds.z) < 0.003)
            return vec4(0.0, 0.0, 0.0, 1.0);
        else
            return vec4(hsv2rgb(vec3(uHcps, vPos.x / bounds.z, 1.0)), 1.0);
    }

    void compose() {
        drawShape(sdRect(bounds), cSQuad());
    }
"""

method draw(cps: ColorPickerS, r: Rect) =
    ## Drawing Hue picker
    let c = currentContext()
    let cc = ColorPickerView(cps.superview).circle.currentColor

    cpSComposition.draw r:
        setUniform("uHcps", cc.h)
        setUniform("uChosenS", cc.s)

method onTouchEv(cps: ColorPickerS, e: var Event): bool =
    let cpv = ColorPickerView(cps.superView)

    if e.buttonState == bsUp:
        cpv.circle.currentColor.s = e.localPosition.x / cps.frame.width
        cpv.chosenColorView.backgroundColor = hsvToRGB(cpv.circle.currentColor)
        cpv.setNeedsDisplay()

    return true

# ColorPickerV

proc newColorPickerV(r: Rect): ColorPickerV =
    ## Saturation picker constructor
    result.new
    result.init(r)

method init(cpv: ColorPickerV, r: Rect) =
    procCall cpv.View.init(r)

var cpVComposition = newComposition """
    uniform float uHcpv;
    uniform float uChosenV;

    vec4 cVQuad() {
        if (abs(uChosenV - vPos.x / bounds.z) < 0.003)
            return vec4(0.0, 0.0, 0.0, 1.0);
        else
            return vec4(hsv2rgb(vec3(uHcpv, 1.0, vPos.x / bounds.z)), 1.0);
    }

    void compose() {
        drawShape(sdRect(bounds), cVQuad());
    }
"""

method draw(cpv: ColorPickerV, r: Rect) =
    ## Drawing Hue picker
    let c = currentContext()
    let cc = ColorPickerView(cpv.superview).circle.currentColor

    cpVComposition.draw r:
        setUniform("uHcpv", cc.h)
        setUniform("uChosenV", cc.v)

method onTouchEv(cpva: ColorPickerV, e: var Event): bool =
    let cpv = ColorPickerView(cpva.superView)

    if e.buttonState == bsUp:
        cpv.circle.currentColor.v = e.localPosition.x / cpva.frame.width
        cpv.chosenColorView.backgroundColor = hsvToRGB(cpv.circle.currentColor)
        cpv.setNeedsDisplay()

    return true

# ColorPickerCircle

proc newColorPickerCircle(defaultPalette: ColorPickerPalette, radius: Coord): ColorPickerCircle =
    result.new
    result.radius = radius
    result.palette = defaultPalette
    result.currentColor = (0.0, 0.0, 0.0)

proc radius*(cpc: ColorPickerCircle): Coord = cpc.radius
    ## Get Color Picker Circle Radius

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

        float diff = abs(uChosenH - h);

        if (diff <= 0.005) {
            return vec4(0.0, 0.0, 0.0, 1.0 - smoothstep(0.003, 0.005, diff));
        } else {
            return vec4(hsv2rgb(vec3(h, s, v)), 1.0);
        }
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
    if e.buttonState == bsUp:
        let radius = cpc.frame.width / 2.0
        let center = newPoint(cpc.frame.width / 2.0, cpc.frame.height / 2.0)

        let h = (arctan2(e.localPosition.y - center.y, center.x - e.localPosition.x) / 3.1415 + 1.0) / 2.0
        let v = 1.0
        let s = sqrt(pow(e.localPosition.x - center.x, 2) + pow(e.localPosition.y - center.y, 2)) / radius

        if s < 1.0 and s > 0.5:
            cpc.currentColor = (h, s, v)
            ColorPickerView(cpc.superview).chosenColorView.backgroundColor = hsvToRGB(cpc.currentColor.h, cpc.currentColor.s, cpc.currentColor.v)
            cpc.superview.setNeedsDisplay()

    return true

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

proc addToHistory*(cpv: ColorPickerView, color: Color) =
    ## Add new color to history
    for hitem in cpv.colorHistory:
        if hitem.backgroundColor == color:
            return
    cpv.colorHistory[cpv.lastInHistory].backgroundColor = color
    cpv.lastInHistory = (cpv.lastInHistory + 1) mod cpv.colorHistory.len()
    cpv.colorHistory[cpv.lastInHistory].setNeedsDisplay()

# ColorView

proc newColorView*(r: Rect, color: Color, main: bool = false): ColorView =
    ## Reactable Color quad constructor
    result.new
    result.init(r)
    result.backgroundColor = color
    result.main = main

method init(cv: ColorView, r: Rect) =
    procCall cv.View.init(r)
    cv.backgroundColor = newGrayColor(1.0)

method onTouchEv(cv: ColorView, e: var Event): bool =
    ## React on click
    discard procCall cv.View.onTouchEv(e)

    if e.buttonState == bsUp:
        if not isNil(cv.superview):
            if not isNil(ColorPickerView(cv.superview).onColorSelected):
                ColorPickerView(cv.superview).onColorSelected(cv.backgroundColor)
            if cv.main:
                addToHistory(ColorPickerView(cv.superview), cv.backgroundColor)

    return true


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
    cpv.chosenColorView = newColorView(newRect(margin * 2.0 + 20, margin * 2.0, r.height / 4.0, r.height / 4.0), newGrayColor(1.0), main = true)
    cpv.addSubview(cpv.chosenColorView)

    let coff = r.height - (20 * 3 + margin * 4)

    # Color history views
    let historyPixelSize = cpv.rightMargin - margin - margin - r.height / 4.0 - 20
    let historySize = (historyPixelSize.int / (r.height / 8.0 + margin.float).int).int

    for hitem in 0 ..< historySize:
        let newItem = newColorView(newRect(
            20 + margin * 3.0 + r.height / 4.0 + r.height / 8.0 * hitem.float + (margin * hitem + 1).float,
            margin * 2.0 + r.height / 8.0,
            r.height / 8.0,
            r.height / 8.0
        ), newGrayColor(1.0))
        cpv.colorHistory.add(newItem)
        cpv.addSubview(newItem)


    # HSV Components
    # HSV Components Labels
    let hLabel = newLabel(cpv, newPoint(margin, coff + margin), newSize(20, 20), "H:")
    let sLabel = newLabel(cpv, newPoint(margin, coff + margin * 2 + 20), newSize(20, 20), "S:")
    let vLabel = newLabel(cpv, newPoint(margin, coff + margin * 3 + 40), newSize(20, 20), "V:")

    # H Component View
    cpv.cpH = newColorPickerH(newRect(margin + 20 + margin, coff + margin, r.width - rightSize - margin * 3.0 - 20, 20))
    cpv.addSubview(cpv.cpH)

    # S Component View
    cpv.cpS = newColorPickerS(newRect(margin + 20 + margin, coff + margin * 2 + 20, r.width - rightSize - margin * 3.0 - 20, 20))
    cpv.addSubview(cpv.cpS)

    # V Component View
    cpv.cpV = newColorPickerV(newRect(margin + 20 + margin, coff + margin * 3 + 40, r.width - rightSize - margin * 3.0 - 20, 20))
    cpv.addSubview(cpv.cpV)
