import control
export control

import composition
import context
import font
import view_event_handling
import app

type Slider* = ref object of Control
    mValue: Coord

var sliderComposition = newComposition """
uniform float uPosition;

void compose() {
    float height = 4.0;
    float knobRadius = bounds.w / 2.0 - 1.0;

    vec4 strokeColor = newGrayColor(0.78);
    float knobX = clamp(bounds.x + bounds.z * uPosition, knobRadius + 0.5, bounds.x + bounds.z - knobRadius - 0.5);

    float y = bounds.y + (bounds.w - height) / 2.0;

    vec4 firstPartRect = vec4(bounds.x, y, bounds.x + knobX, height);
    vec4 secondPartRect = vec4(firstPartRect.z, y, bounds.x + bounds.z - knobX, height);
    drawShape(sdRoundedRect(firstPartRect, height / 2.0), vec4(0.25, 0.60, 0.98, 1.0));
    drawShape(sdRoundedRect(secondPartRect, height / 2.0), strokeColor);

    vec2 center = vec2(knobX, bounds.y + bounds.w / 2.0);
    drawShape(sdCircle(center, knobRadius), strokeColor);
    drawShape(sdCircle(center, knobRadius - 1.0), newGrayColor(1.0));
}
"""

method draw*(s: Slider, r: Rect) =
    sliderComposition.draw s.bounds:
        setUniform("uPosition", s.mValue)

proc `value=`*(s: Slider, p: Coord) =
    s.mValue = p
    if p < 0: s.mValue = 0
    elif p > 1: s.mValue = 1
    s.setNeedsDisplay()

template value*(s: Slider): Coord = s.mValue

method onMouseDown(s: Slider, e: var Event): bool =
    result = true
    s.value = e.localPosition.x / s.bounds.width

    mainApplication().pushEventFilter do(e: var Event, c: var EventFilterControl) -> bool:
        result = true
        if e.kind == etMouse:
            e.localPosition = s.convertPointFromWindow(e.position)
            if e.isButtonUpEvent():
                c = efcBreak
                result = s.onMouseUp(e)
            elif e.isMouseMoveEvent():
                s.value = e.localPosition.x / s.bounds.width
                s.setNeedsDisplay()
                s.sendAction(e)

method onMouseUp(s: Slider, e: var Event): bool =
    result = true
    s.sendAction(e)
