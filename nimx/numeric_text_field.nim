import strutils, math, times
import nimx / [keyboard, text_field, formatted_text, 
    view_event_handling, window_event_handling, composition,
    context, font, animation, window]

type NumericTextField* = ref object of TextField
    precision*: uint
    initialMouseTime: float
    initialMouseX: Coord
    mouseX: Coord
    touchAnim: Animation
    directionLeft: bool

proc newNumericTextField*(gfx: GraphicsContext, r: Rect, precision: uint = 2): NumericTextField =
    result.new()
    result.init(gfx, r)
    result.precision = precision

method init*(v: NumericTextField, gfx: GraphicsContext, r: Rect) =
    procCall v.TextField.init(gfx, r)
    v.precision = 2
    v.formattedText.horizontalAlignment = haCenter

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
    template c: untyped = v.gfx
    draw c, arrowComposition, newRect(0, 0, arrowMargin, v.bounds.height):
        setUniform("uAngle", Coord(PI))
    draw c, arrowComposition, newRect(v.bounds.width - arrowMargin, 0, arrowMargin, v.bounds.height):
        setUniform("uAngle", Coord(0))

method draw*(t: NumericTextField, r: Rect) =
    procCall t.TextField.draw(r)
    if not t.isFirstResponder():
        t.drawArrows()

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
