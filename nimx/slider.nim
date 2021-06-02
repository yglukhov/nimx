import control
export control

import composition
import context
import view_event_handling

type Slider* = ref object of Control
    mValue: Coord

var sliderComposition = newComposition """
uniform float uPosition;

void compose() {
    float lineWidth = 4.0;
    float knobRadius = min(bounds.w, bounds.z) / 2.0 - 1.0;

    vec4 strokeColor = newGrayColor(0.78);

    if (bounds.z > bounds.w) { // Horizontal
        float knobPos = clamp(bounds.x + bounds.z * uPosition, knobRadius + 0.5, bounds.x + bounds.z - knobRadius - 0.5);

        float y = bounds.y + (bounds.w - lineWidth) / 2.0;

        vec4 firstPartRect = vec4(bounds.x, y, bounds.x + knobPos, lineWidth);
        vec4 secondPartRect = vec4(firstPartRect.z, y, bounds.x + bounds.z - knobPos, lineWidth);
        drawShape(sdRoundedRect(firstPartRect, lineWidth / 2.0), vec4(0.25, 0.60, 0.98, 1.0));
        drawShape(sdRoundedRect(secondPartRect, lineWidth / 2.0), strokeColor);

        vec2 center = vec2(knobPos, bounds.y + bounds.w / 2.0);
        drawShape(sdCircle(center, knobRadius), strokeColor);
        drawShape(sdCircle(center, knobRadius - 1.0), newGrayColor(1.0));
    }
    else { // Vertical
        float knobPos = clamp(bounds.y + bounds.w * uPosition, knobRadius + 0.5, bounds.y + bounds.w - knobRadius - 0.5);

        float x = bounds.x + (bounds.z - lineWidth) / 2.0;

        vec4 firstPartRect = vec4(x, bounds.y, lineWidth, bounds.y + knobPos);
        vec4 secondPartRect = vec4(x, firstPartRect.w, lineWidth, bounds.y + bounds.w - knobPos);
        drawShape(sdRoundedRect(firstPartRect, lineWidth / 2.0), vec4(0.25, 0.60, 0.98, 1.0));
        drawShape(sdRoundedRect(secondPartRect, lineWidth / 2.0), strokeColor);

        vec2 center = vec2(bounds.x + bounds.z / 2.0, knobPos);
        drawShape(sdCircle(center, knobRadius), strokeColor);
        drawShape(sdCircle(center, knobRadius - 1.0), newGrayColor(1.0));
    }
}
"""

method draw*(s: Slider, r: Rect) =
    draw s.window.gfxCtx, sliderComposition, s.bounds:
        setUniform("uPosition", s.mValue)

proc `value=`*(s: Slider, p: Coord) =
    s.mValue = p
    if p < 0: s.mValue = 0
    elif p > 1: s.mValue = 1
    s.setNeedsDisplay()

template value*(s: Slider): Coord = s.mValue

template isHorizontal*(s: Slider): bool = s.bounds.width > s.bounds.height

method onTouchEv(s: Slider, e: var Event): bool =
    result = true
    discard procCall s.View.onTouchEv(e)
    case e.buttonState
    of bsDown:
        if s.isHorizontal:
            s.value = e.localPosition.x / s.bounds.width
        else:
            s.value = e.localPosition.y / s.bounds.height
    of bsUnknown:
        if s.isHorizontal:
            s.value = e.localPosition.x / s.bounds.width
        else:
            s.value = e.localPosition.y / s.bounds.height
        s.setNeedsDisplay()
        s.sendAction(e)
    of bsUp:
        s.sendAction(e)
        result = false

registerClass(Slider)
