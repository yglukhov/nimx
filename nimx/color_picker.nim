import math

import view
export view

import context
import composition
import types
import portable_gl
import popup_button
import strutils
import text_field
import view_event_handling
import view_dragging_listener
import button

import nimx / meta_extensions / [ property_desc, visitors_gen, serializers_gen ]

const
    margin = 6

type
    ColorPickerPalette* {.pure.} = enum
        HSV

    ColorComponent* {.pure.} = enum
        H
        S
        V

    ColorView* = ref object of View
        ## Color quad that reacts to outer world
        main: bool    ## Defines if view is main or from history

    ColorPickerCircle* = ref object of View
        radius: Coord
        palette: ColorPickerPalette

    ColorPickerH* = ref object of View
        ## Hue tuning widget

    ColorPickerS* = ref object of View
        ## Saturation tuning widget

    ColorPickerV* = ref object of View
        ## Value tuning widget

    ColorComponentTextField = ref object of TextField
        cComponent: ColorComponent

    ColorPickerView* = ref object of View
        ## Complex Widget that allows to pick color using HSV palette
        palette:         ColorPickerPalette  ## Palette (RGB, HSV, HSL, etc.)
        colorHistory:    seq[ColorView]      ## History of chosen colors
        lastInHistory:   int                 ## Last item index added to history

        currentColor: tuple[h: float, s: float, v: float]
        circle*:         ColorPickerCircle   ## Color picking circle
        paletteChooser:  PopupButton         ## Palette choser popup
        chosenColorView: View                ## Quad that shows current color

        cpH: ColorPickerH                    ## Hue tuning widget
        cpS: ColorPickerS                    ## Saturation tuning widget
        cpV: ColorPickerV                    ## Value tuning widget

        tfH: TextField                       ## Hue numerical widget
        tfS: TextField                       ## Saturation numerical widget
        tfV: TextField                       ## Value numerical widget

        # Graphics metrics
        rightMargin:     Coord               ## Circle offset (layout-helper)

        # Callbacks
        onColorSelected*: proc(c: Color) {.gcsafe.}

template enclosingColorPickerView(v: View): ColorPickerView = v.enclosingViewOfType(ColorPickerView)

proc newColorComponentTextField(r: Rect, comp: ColorComponent): ColorComponentTextField =
    result.new
    result.init(r)
    result.cComponent = comp
    result.textColor = newGrayColor(0.0)

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

proc rgbToHSV*(r: float, g: float, b: float): tuple[h: float, s: float, v: float] =
    var max = r
    if (max < g): max = g
    if (max < b): max = b
    var min = r
    if (min > g): min = g
    if (min > b): min = b

    result.v = max

    if (max == min):
        return result
    elif (max == r):
        result.h = 60.0 * (g - b) / (max - min)
        if (result.h < 0.0): result.h += 360.0
        if (result.h >= 360.0): result.h -= 360.0
    elif (max == g):
        result.h = 60.0 * (b - r) / (max - min) + 120.0
    elif (max == b):
        result.h = 60.0 * (r - g) / (max - min) + 240.0

    result.h /= 360.0

    if (max == 0): result.s = 0.0
    else: result.s = 1.0 - (min / max)

proc hsvToRgb(color: tuple[h: float, s: float, v: float]): Color =
    hsvToRgb(color.h, color.s, color.v)

# ColorPickerH

proc newColorPickerH(r: Rect): ColorPickerH =
    ## Hue picker constructor
    result.new
    result.init(r)

method init(cph: ColorPickerH, r: Rect) =
    procCall cph.View.init(r)

const cpHComposition = newComposition """
    uniform float uChosenH;

    vec4 cHQuad() {
        if (distance(vPos.x, uChosenH * bounds.z) < 1.0)
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
    let h = cph.enclosingColorPickerView().currentColor.h

    cpHComposition.draw r:
        setUniform("uChosenH", h)

proc colorHasChanged(cpv: ColorPickerView) =
    ## Perform update of ColorPickerView components
    cpv.tfH.text = formatFloat(cpv.currentColor.h, precision = 3)
    cpv.tfS.text = formatFloat(cpv.currentColor.s, precision = 3)
    cpv.tfV.text = formatFloat(cpv.currentColor.v, precision = 3)
    cpv.chosenColorView.backgroundColor = hsvToRGB(cpv.currentColor)
    cpv.setNeedsDisplay()

method onTextInput(ccf: ColorComponentTextField, s: string): bool =
    discard procCall ccf.TextField.onTextInput(s)

    let val = try: parseFloat(ccf.text)
              except Exception: -100.0
    if val == -100.0: return true

    let cpv = ccf.enclosingColorPickerView()

    case ccf.cComponent
    of ColorComponent.H:
        cpv.currentColor.h = val
    of ColorComponent.S:
        cpv.currentColor.s = val
    of ColorComponent.V:
        cpv.currentColor.v = val

    cpv.colorHasChanged()

    return true

method onTouchEv(cph: ColorPickerH, e: var Event): bool {.gcsafe.}=
    let cpv = cph.enclosingColorPickerView()

    if e.buttonState == bsUp or true:
        var h = e.localPosition.x / cph.frame.width
        h = h.clamp(0.0, 1.0)
        cpv.currentColor.h = h
        cpv.colorHasChanged()

        if not isNil(cpv.onColorSelected):
            cpv.onColorSelected(hsvToRGB(cpv.currentColor.h, cpv.currentColor.s, cpv.currentColor.v))

    return true

# ColorPickerS

proc newColorPickerS(r: Rect): ColorPickerS =
    ## Saturation picker constructor
    result.new
    result.init(r)

method init(cps: ColorPickerS, r: Rect) =
    procCall cps.View.init(r)

const cpSComposition = newComposition """
    uniform float uHcps;
    uniform float uChosenS;

    vec4 cSQuad() {
        if (distance(vPos.x, uChosenS * bounds.z) < 1.0)
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
    let cc = cps.enclosingColorPickerView().currentColor

    cpSComposition.draw r:
        setUniform("uHcps", cc.h)
        setUniform("uChosenS", cc.s)

method onTouchEv(cps: ColorPickerS, e: var Event): bool =
    let cpv = cps.enclosingColorPickerView()

    if e.buttonState == bsUp or true:
        var s = e.localPosition.x / cps.frame.width
        s = s.clamp(0.0, 1.0)
        cpv.currentColor.s = s
        cpv.colorHasChanged()

        if not isNil(cpv.onColorSelected):
            cpv.onColorSelected(hsvToRGB(cpv.currentColor.h, cpv.currentColor.s, cpv.currentColor.v))

    return true

# ColorPickerV

proc newColorPickerV(r: Rect): ColorPickerV =
    ## Saturation picker constructor
    result.new
    result.init(r)

method init(cpv: ColorPickerV, r: Rect) =
    procCall cpv.View.init(r)

const cpVComposition = newComposition """
    uniform float uHcpv;
    uniform float uChosenV;

    vec4 cVQuad() {
        if (distance(vPos.x, uChosenV * bounds.z) < 1.0)
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
    let cc = cpv.enclosingColorPickerView().currentColor

    cpVComposition.draw r:
        setUniform("uHcpv", cc.h)
        setUniform("uChosenV", cc.v)

method onTouchEv(cpva: ColorPickerV, e: var Event): bool =
    let cpv = cpva.enclosingColorPickerView()

    if e.buttonState == bsUp or true:
        var v = (e.localPosition.x / cpva.frame.width).clamp(0.0, 1.0)
        v = v.clamp(0.0, 1.0)
        cpv.currentColor.v = v
        cpv.colorHasChanged()

        if not isNil(cpv.onColorSelected):
            cpv.onColorSelected(hsvToRGB(cpv.currentColor.h, cpv.currentColor.s, cpv.currentColor.v))

    return true

# ColorPickerCircle

proc newColorPickerCircle(defaultPalette: ColorPickerPalette, radius: Coord, frame: Rect): ColorPickerCircle =
    result = ColorPickerCircle.new(frame)
    result.radius = radius
    result.palette = defaultPalette

proc radius*(cpc: ColorPickerCircle): Coord = cpc.radius
    ## Get Color Picker Circle Radius

const hsvCircleComposition = newComposition """
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

method draw*(cpc: ColorPickerCircle, r: Rect) =
    ## Custom palette drawing
    let c = currentContext()
    let cpv = cpc.enclosingColorPickerView()

    # Draw hsv circle
    c.fillColor = newGrayColor(0.0, 0.0)
    c.strokeColor = newGrayColor(0.0, 0.0)

    hsvCircleComposition.draw cpc.bounds:
        setUniform("uHsvValue", 1.0)
        setUniform("uChosenH", cpv.currentColor.h)

method onTouchEv*(cpc: ColorPickerCircle, e: var Event): bool =
    ## Choose color
    if e.buttonState == bsUp or true:
        let radius = cpc.frame.width / 2.0
        let center = newPoint(cpc.frame.width / 2.0, cpc.frame.height / 2.0)

        let cpv = cpc.enclosingColorPickerView()

        cpv.currentColor.h = (arctan2(e.localPosition.y - center.y, center.x - e.localPosition.x) / 3.1415 + 1.0) / 2.0
        cpv.colorHasChanged()

        if not isNil(cpv.onColorSelected):
            cpv.onColorSelected(hsvToRGB(cpv.currentColor.h, cpv.currentColor.s, cpv.currentColor.v))

    return true

# ColorPickerView

proc newColorPickerView*(r: Rect, defaultPalette = ColorPickerPalette.HSV, backgroundColor: Color = newGrayColor(0.35, 0.8)): ColorPickerView =
    ## ColorPickerView constructor
    result.new
    result.init(r)
    result.palette = defaultPalette
    result.backgroundColor = backgroundColor
    result.enableDraggingByBackground()

proc currentColor*(cpv: ColorPickerView): Color =
    ## Return current chosen color
    hsvToRGB(cpv.currentColor.h, cpv.currentColor.s, cpv.currentColor.v)

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
    let circleRadius = (rightSize - 2.0 * margin) / 2.0
    let circleRect = newRect(cpv.rightMargin + margin, margin, rightSize - margin, rightSize - margin)

    cpv.circle = newColorPickerCircle(ColorPickerPalette.HSV, circleRadius, circleRect)
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
    cpv.tfH = newColorComponentTextField(newRect(margin + 20 + margin, coff + margin, 40, 20), ColorComponent.H)
    cpv.tfH.text = $cpv.currentColor.h
    cpv.addSubview(cpv.tfH)

    cpv.cpH = newColorPickerH(newRect(margin + 20 + 40 + margin + margin, coff + margin, r.width - rightSize - 40 - margin * 4.0 - 20, 20))
    cpv.addSubview(cpv.cpH)

    # S Component View
    cpv.tfS = newColorComponentTextField(newRect(margin + 20 + margin, coff + margin * 2 + 20, 40, 20), ColorComponent.S)
    cpv.tfS.text = $cpv.currentColor.s
    cpv.addSubview(cpv.tfS)

    cpv.cpS = newColorPickerS(newRect(margin + 20 + 40 + margin + margin, coff + margin * 2 + 20, r.width - rightSize - 40 - margin * 4.0 - 20, 20))
    cpv.addSubview(cpv.cpS)

    # V Component View
    cpv.tfV = newColorComponentTextField(newRect(margin + 20 + margin, coff + margin * 3 + 40, 40, 20), ColorComponent.V)
    cpv.tfV.text = $cpv.currentColor.v
    cpv.addSubview(cpv.tfV)

    cpv.cpV = newColorPickerV(newRect(margin + 20 + 40 + margin + margin, coff + margin * 3 + 40, r.width - rightSize - 40 - margin * 4.0 - 20, 20))
    cpv.addSubview(cpv.cpV)

proc `color=`*(v: ColorPickerView, c: Color) =
    v.currentColor = rgbToHSV(c.r, c.g, c.b)
    v.colorHasChanged()

proc color*(v: ColorPickerView): Color = hsvToRGB(v.currentColor)

var gColorPicker: ColorPickerView

proc sharedColorPicker*(): ColorPickerView =
    if gColorPicker.isNil:
        gColorPicker = newColorPickerView(newRect(0, 0, 300, 200))
    result = gColorPicker

proc popupAtPoint*(c: ColorPickerView, v: View, p: Point) =
    c.removeFromSuperview()
    c.setFrameOrigin(v.convertPointToWindow(p))
    v.window.addSubview(c)

ColorPickerView.properties:
    rightMargin

const colorCreat = proc(): RootRef = newColorPickerView(zeroRect)
registerClass(ColorPickerView, colorCreat)
genVisitorCodeForView(ColorPickerView)
genSerializeCodeForView(ColorPickerView)
