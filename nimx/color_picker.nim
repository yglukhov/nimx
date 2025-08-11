import std/[math, parseutils]
import strutils

import view
export view

import ./[context, layout, composition, types, portable_gl, popup_button, text_field,
          view_event_handling, view_dragging_listener, button]
import ./meta_extensions/[ property_desc, visitors_gen, serializers_gen ]

const
  margin = 6

type
  ColorPickerPalette* {.pure.} = enum
    HSV

  ColorView* = ref object of View
    ## Color quad that reacts to outer world
    main: bool  ## Defines if view is main or from history

  ColorPickerCircle* = ref object of View
    palette: ColorPickerPalette

  ColorPickerH* = ref object of View
    ## Hue tuning widget

  ColorPickerS* = ref object of View
    ## Saturation tuning widget

  ColorPickerV* = ref object of View
    ## Value tuning widget

  ColorPickerView* = ref object of Control
    ## Complex Widget that allows to pick color using HSV palette
    palette:     ColorPickerPalette  ## Palette (RGB, HSV, HSL, etc.)

    currentColor: tuple[h, s, v: float]
    circle:      ColorPickerCircle   ## Color picking circle
    chosenColorView: ColorView       ## Quad that shows current color

    cpH: ColorPickerH          ## Hue tuning widget
    cpS: ColorPickerS          ## Saturation tuning widget
    cpV: ColorPickerV          ## Value tuning widget

    tfH: TextField             ## Hue numerical widget
    tfS: TextField             ## Saturation numerical widget
    tfV: TextField             ## Value numerical widget

template enclosingColorPickerView(v: View): ColorPickerView = v.enclosingViewOfType(ColorPickerView)

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
  cpv.tfH.text = formatFloat(cpv.currentColor.h, ffDecimal, 3)
  cpv.tfS.text = formatFloat(cpv.currentColor.s, ffDecimal, 3)
  cpv.tfV.text = formatFloat(cpv.currentColor.v, ffDecimal, 3)
  cpv.chosenColorView.backgroundColor = hsvToRGB(cpv.currentColor)
  cpv.setNeedsDisplay()

method onTouchEv(cph: ColorPickerH, e: var Event): bool {.gcsafe.}=
  let cpv = cph.enclosingColorPickerView()

  if e.buttonState == bsUp or true:
    var h = e.localPosition.x / cph.frame.width
    h = h.clamp(0.0, 1.0)
    cpv.currentColor.h = h
    cpv.colorHasChanged()
    cpv.sendAction(e)

  return true

# ColorPickerS
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
    cpv.sendAction(e)

  return true

# ColorPickerV
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
    cpv.sendAction(e)

  return true

# ColorPickerCircle

const hsvCircleComposition = newComposition """
  uniform float uHsvValue;
  uniform float uChosenH;

  vec4 cHsvCircle() {
    float r = bounds.z / 2.0;
    vec2 c = vec2(bounds.xy + (bounds.zw / 2.0));
    float h = (atan(vPos.y - c.y, c.x - vPos.x) / PI + 1.0) / 2.0;
    float s = distance(vPos, c) / r;
    float v = uHsvValue;

    float diff = min(min(abs(uChosenH - h), abs(uChosenH + 1.0 - h)), abs(uChosenH - 1.0 - h));
    float d = fwidth(diff);
    return vec4(mix(vec3(0), hsv2rgb(vec3(h, s, v)), smoothstep(0.005 - d, 0.005 + d, diff)), 1);
  }

  void compose() {
    drawShape(sdEllipseInRect(bounds), cHsvCircle());
    drawShape(sdEllipseInRect(vec4(bounds.xy + bounds.z / 4.0, bounds.zw / 2.0)), vec4(0));
  }
"""

method draw*(cpc: ColorPickerCircle, r: Rect) =
  ## Custom palette drawing
  let c = currentContext()
  let cpv = cpc.enclosingColorPickerView()

  # Draw hsv circle
  c.fillColor = newGrayColor(0.0, 0.0)
  c.strokeColor = newGrayColor(0.0, 0.0)

  var r = cpc.bounds
  let d = min(r.size.width, r.size.height)
  r.size = newSize(d, d)

  hsvCircleComposition.draw r.centerInRect(cpc.bounds):
    setUniform("uHsvValue", 1.0)
    setUniform("uChosenH", cpv.currentColor.h)

method onTouchEv*(cpc: ColorPickerCircle, e: var Event): bool =
  ## Choose color
  if e.buttonState == bsUp or true:
    let center = newPoint(cpc.frame.width / 2.0, cpc.frame.height / 2.0)

    let cpv = cpc.enclosingColorPickerView()

    cpv.currentColor.h = (arctan2(e.localPosition.y - center.y, center.x - e.localPosition.x) / 3.1415 + 1.0) / 2.0
    cpv.colorHasChanged()
    cpv.sendAction(e)

  return true

# ColorPickerView

proc newColorPickerView*(r: Rect, defaultPalette = ColorPickerPalette.HSV, backgroundColor: Color = newGrayColor(0.35, 0.8)): ColorPickerView =
  ## ColorPickerView constructor
  result = ColorPickerView.new()
  result.palette = defaultPalette
  result.backgroundColor = backgroundColor
  result.enableDraggingByBackground()

proc currentColor*(cpv: ColorPickerView): Color =
  ## Return current chosen color
  hsvToRGB(cpv.currentColor.h, cpv.currentColor.s, cpv.currentColor.v)

# ColorView
method init(cv: ColorView) =
  procCall cv.View.init()
  cv.backgroundColor = newGrayColor(1.0)

method onTouchEv(cv: ColorView, e: var Event): bool =
  ## React on click
  discard procCall cv.View.onTouchEv(e)

  if e.buttonState == bsUp:
    if not isNil(cv.superview):
      ColorPickerView(cv.superview).sendAction(e)
      # if cv.main:
      #   addToHistory(ColorPickerView(cv.superview), cv.backgroundColor)

  return true

proc updateColorFromTextField(c: ColorPickerView, tf: TextField, value: var float) =
  let t = tf.text
  if parseFloat(t, value) != t.len:
    value = -100
  let curp = tf.cursorPosition
  c.colorHasChanged()
  tf.text = t
  tf.cursorPosition = curp

method init*(cpv: ColorPickerView) =
  # Basic Properties Initialization
  procCall cpv.View.init()

  cpv.makeLayout:
    - ColorPickerCircle as circle:
      trailing == super - margin
      y == super + margin
      bottom == super - margin
      width == super / 3
      palette: ColorPickerPalette.HSV

    - Label:
      leading == super + margin
      size == [20, 20]
      bottom == labelS.layout.vars.top - margin
      text: "H: "

    - TextField as tfH:
      leading == prev.trailing + margin
      width == 60
      y == prev
      height == prev
      continuous: true
      onAction:
        updateColorFromTextField(cpv, tFH, cpv.currentColor.h)

    - ColorPickerH as cpH:
      leading == prev.trailing + margin
      trailing == circle.layout.vars.leading - margin
      y == prev
      height == prev

    - Label as labelS:
      leading == super + margin
      size == [20, 20]
      bottom == labelV.layout.vars.top - margin
      text: "S: "

    - TextField as tfS:
      leading == prev.trailing + margin
      width == tfH.layout.vars.width
      y == prev
      height == prev
      continuous: true
      onAction:
        updateColorFromTextField(cpv, tFS, cpv.currentColor.s)

    - ColorPickerS as cpS:
      leading == prev.trailing + margin
      trailing == circle.layout.vars.leading - margin
      y == prev
      height == prev

    - Label as labelV:
      leading == super + margin
      size == [20, 20]
      bottom == super - margin
      text: "V: "

    - TextField as tfV:
      leading == prev.trailing + margin
      width == tfH.layout.vars.width
      y == prev
      height == prev
      continuous: true
      onAction:
        updateColorFromTextField(cpv, tFV, cpv.currentColor.v)

    - ColorPickerV as cpB:
      leading == prev.trailing + margin
      trailing == circle.layout.vars.leading - margin
      y == prev
      height == prev

    - ColorView as selectedColorView:
      leading == super + margin
      y == super + margin
      height == 50
      width == self.height

  cpv.circle = circle
  cpv.chosenColorView = selectedColorView
  cpv.tfH = tfH
  cpv.cpH = cpH
  cpv.tfS = tfS
  cpv.cpS = cpS
  cpv.tfV = tfV
  cpv.cpV = cpB
  cpv.currentColor = (0.5, 0.5, 0.5)
  cpv.colorHasChanged()

proc `color=`*(v: ColorPickerView, c: Color) =
  v.currentColor = rgbToHSV(c.r, c.g, c.b)
  v.colorHasChanged()

proc color*(v: ColorPickerView): Color = hsvToRGB(v.currentColor)

var gColorPicker {.threadvar.}: ColorPickerView

# proc sharedColorPicker*(): ColorPickerView =
#   if gColorPicker.isNil:
#     gColorPicker = newColorPickerView(newRect(0, 0, 300, 200))
#   result = gColorPicker

# proc popupAtPoint*(c: ColorPickerView, v: View, p: Point) =
#   c.removeFromSuperview()
#   c.setFrameOrigin(v.convertPointToWindow(p))
#   v.window.addSubview(c)

# ColorPickerView.properties:
#   rightMargin

registerClass(ColorPickerView)
genVisitorCodeForView(ColorPickerView)
genSerializeCodeForView(ColorPickerView)
