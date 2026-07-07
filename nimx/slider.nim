import control
export control

import composition
import context
import view_event_handling

type Slider* = ref object of Control
  mValue: Coord

const sliderComposition = newComposition """
fn compose() {
  let lineWidth = 4.0;
  let knobRadius = min(uni.bounds.w, uni.bounds.z) / 2.0 - 1.0;
  let strokeColor = newGrayColor(0.78);

  if (uni.bounds.z > uni.bounds.w) {
    let knobPos = clamp(uni.bounds.x + uni.bounds.z * uni.uPosition.x, knobRadius + 0.5, uni.bounds.x + uni.bounds.z - knobRadius - 0.5);
    let y = uni.bounds.y + (uni.bounds.w - lineWidth) / 2.0;
    let firstPartRect = vec4f(uni.bounds.x, y, uni.bounds.x + knobPos, lineWidth);
    let secondPartRect = vec4f(firstPartRect.z, y, uni.bounds.x + uni.bounds.z - knobPos, lineWidth);
    drawShape(sdRoundedRectAt(firstPartRect, lineWidth / 2.0), vec4f(0.25, 0.60, 0.98, 1.0));
    drawShape(sdRoundedRectAt(secondPartRect, lineWidth / 2.0), strokeColor);
    let center = vec2f(knobPos, uni.bounds.y + uni.bounds.w / 2.0);
    drawShape(sdCircleAt(center, knobRadius), strokeColor);
    drawShape(sdCircleAt(center, knobRadius - 1.0), newGrayColor(1.0));
  } else {
    let knobPos = clamp(uni.bounds.y + uni.bounds.w * uni.uPosition.x, knobRadius + 0.5, uni.bounds.y + uni.bounds.w - knobRadius - 0.5);
    let x = uni.bounds.x + (uni.bounds.z - lineWidth) / 2.0;
    let firstPartRect = vec4f(x, uni.bounds.y, lineWidth, uni.bounds.y + knobPos);
    let secondPartRect = vec4f(x, firstPartRect.w, lineWidth, uni.bounds.y + uni.bounds.w - knobPos);
    drawShape(sdRoundedRectAt(firstPartRect, lineWidth / 2.0), vec4f(0.25, 0.60, 0.98, 1.0));
    drawShape(sdRoundedRectAt(secondPartRect, lineWidth / 2.0), strokeColor);
    let center = vec2f(uni.bounds.x + uni.bounds.z / 2.0, knobPos);
    drawShape(sdCircleAt(center, knobRadius), strokeColor);
    drawShape(sdCircleAt(center, knobRadius - 1.0), newGrayColor(1.0));
  }
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
