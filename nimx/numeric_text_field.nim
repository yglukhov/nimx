import strutils, math, times
import nimx.keyboard
import nimx.text_field
import nimx.view_event_handling
import nimx.window_event_handling
import nimx.composition
import nimx.context
import nimx.font
import nimx.animation
import nimx.window

type NumericTextField* = ref object of TextField
    precision*: uint
    initialMouseTime: float
    initialMouseX: Coord
    mouseX: Coord
    touchAnim: Animation
    directionLeft: bool

proc newNumericTextField*(r: Rect, precision: uint = 2): NumericTextField =
    result.new()
    result.init(r)
    result.precision = precision

method init*(v: NumericTextField, r: Rect) =
    procCall v.TextField.init(r)
    v.precision = 2

#[
method onScroll*(v: NumericTextField, e: var Event): bool =
    result = true
    var action = false
    try:
        var val = parseFloat(v.text)
        if VirtualKey.LeftControl in e.modifiers:
            val += e.offset.y * 0.1
        elif VirtualKey.LeftShift in e.modifiers:
            val += e.offset.y * 10
        else:
            val += e.offset.y
        v.text = formatFloat(val, ffDecimal, v.precision)
        action = true
        v.setNeedsDisplay()
    except:
        discard
    if action:
        v.sendAction()
]#

var arrowComposition = newComposition """
uniform float uAngle;

void compose() {
    vec2 center = vec2(bounds.x + bounds.z / 2.0, bounds.y + bounds.w / 2.0 - 1.0);
    float triangle = sdRegularPolygon(center, 4.0, 3, uAngle);
    drawShape(triangle, vec4(0.7, 0.7, 0.7, 1));
}
"""

proc drawArrows(v: NumericTextField) =
    const arrowMargin = 10
    arrowComposition.draw newRect(0, 0, arrowMargin, v.bounds.height):
        setUniform("uAngle", Coord(PI))
    arrowComposition.draw newRect(v.bounds.width - arrowMargin, 0, arrowMargin, v.bounds.height):
        setUniform("uAngle", Coord(0))

method draw*(t: NumericTextField, r: Rect) =
    if not t.isFirstResponder():
        let c = currentContext()
        c.fillColor = whiteColor()
        c.strokeColor = newGrayColor(0.74)
        c.strokeWidth = 1.0
        c.drawRect(t.bounds)
        t.drawArrows()

        if t.text != nil:
            let font = t.font()
            let sz = font.sizeOfString(t.text)
            var pt = sz.centerInRect(t.bounds)
            c.fillColor = t.textColor
            c.drawText(font, pt, t.text)
    else:
        procCall t.TextField.draw(r)

#[
proc roundTo(v, t: float): float =
    let vv = abs(v)
    let m = vv mod t
    if m > t / 2:
        result = vv + (t - m)
    else:
        result = vv - m
    if v < 0: result = -result
 ]#

method onTouchEv*(t: NumericTextField, e: var Event): bool =
    if t.isFirstResponder():
        return procCall t.TextField.onTouchEv(e)

    case e.buttonState
    of bsDown:
        t.initialMouseTime = epochTime()

        t.initialMouseX = e.localPosition.x
        t.mouseX = t.initialMouseX

        var val = try: parseFloat(t.text)
                  except: 0.0

        t.touchAnim = newAnimation()
        t.touchAnim.loopDuration = 1.0
        t.touchAnim.numberOfLoops = -1
        t.touchAnim.onAnimate = proc(p: float)=
            let diff = t.initialMouseX - t.mouseX
            let absDiff = abs(diff)
            if absDiff > 0.0:
                val = val - (diff) / (10000.0 / absDiff)
                t.text = formatFloat(val, ffDecimal, t.precision)
                t.sendAction()

        t.window.addAnimation(t.touchAnim)

        result = true

    of bsUp:
        if epochTime() - t.initialMouseTime < 0.3:
            result = t.makeFirstResponder()

        t.mouseX = t.initialMouseX
        t.touchAnim.cancel()
        t.touchAnim = nil

    of bsUnknown:
        var direction = t.mouseX > e.localPosition.x
        if direction != t.directionLeft:
            t.directionLeft = direction
            t.initialMouseX = e.localPosition.x
        t.mouseX = e.localPosition.x
        result = true
