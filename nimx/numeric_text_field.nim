import strutils, math, times
import nimx.keyboard
import nimx.text_field
import nimx.view_event_handling
import nimx.window_event_handling
import nimx.composition
import nimx.context
import nimx.font

type NumericTextField* = ref object of TextField
    precision*: uint
    initialMouseTime: float
    prevMouseTime: float
    prevMouseX: Coord
    mouseSpeed: Coord
    prevDirLeft: bool

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
        if alsoPressed(VirtualKey.LeftControl):
            val += e.offset.y * 0.1
        elif alsoPressed(VirtualKey.LeftShift):
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

proc roundTo(v, t: float): float =
    let vv = abs(v)
    let m = vv mod t
    if m > t / 2:
        result = vv + (t - m)
    else:
        result = vv - m
    if v < 0: result = -result

method onTouchEv*(t: NumericTextField, e: var Event): bool =
    if t.isFirstResponder():
        return procCall t.TextField.onTouchEv(e)

    case e.buttonState
    of bsDown:
        t.initialMouseTime = epochTime()
        t.prevMouseTime = t.initialMouseTime
        t.prevMouseX = e.localPosition.x
        t.mouseSpeed = 0
        result = true
    of bsUp:
        if epochTime() - t.initialMouseTime < 0.3:
            result = t.makeFirstResponder()
            t.selectAll()

    of bsUnknown:
        result = true
        let curTime = epochTime()
        let mouseDistance = e.localPosition.x - t.prevMouseX
        let dirLeft = mouseDistance < 0
        if dirLeft != t.prevDirLeft:
            t.mouseSpeed = 0
            t.prevDirLeft = dirLeft

        if curTime - t.prevMouseTime < 0.001: return

        let mouseSpeed = abs(mouseDistance) / (curTime - t.prevMouseTime)
        t.mouseSpeed = t.mouseSpeed * 0.75 + mouseSpeed * 0.25
        let delta = mouseDistance * sqrt(t.mouseSpeed) * 0.05
        # echo "mouseSpeed ", mouseSpeed, " mouseDistance ", mouseDistance, " curTime ", curTime, " t.prevMouseTime ", t.prevMouseTime, " delta ", delta, " e.localPosition ", e.localPosition
        t.prevMouseX = e.localPosition.x
        t.prevMouseTime = curTime
        var action = false
        try:
            var val = parseFloat(t.text) + delta
            if abs(t.mouseSpeed) > 1000:
                val = val.roundTo(100)
            elif abs(t.mouseSpeed) > 500:
                val = val.roundTo(10)
            elif abs(t.mouseSpeed) > 50:
                val = val.roundTo(1)

            t.text = formatFloat(val, ffDecimal, t.precision)
            action = true
        except:
            discard
        if action:
            t.sendAction()
