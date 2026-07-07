import view
export view

import composition
import animation
import abstract_window

import times
import math

type ProgressIndicator* = ref object of View
  mValue: Coord
  mIndeterminate: bool
  animation: Animation

const piComposition = newComposition """
const radius: f32 = 5.0;
fn compose() {
  let stroke = sdRoundedRectAt(uni.bounds, radius);
  let fill = sdRoundedRectAt(insetRect(uni.bounds, 1.0), radius - 1.0);
  drawShape(stroke, newGrayColor(0.78));
  drawShape(fill, newGrayColor(0.88));
  var progressRect = uni.bounds;
  progressRect.z *= uni.uPosition.x;
  let fc = gradient5(smoothstep(uni.bounds.y, uni.bounds.y + uni.bounds.w, vPos.y),
    vec4f(0.71, 0.80, 0.88, 1.0),
    0.5, vec4f(0.32, 0.68, 0.95, 1.0),
    vec4f(0.71, 0.80, 0.88, 1.0));
  drawShape(sdAnd(fill, sdRectAt(progressRect)), fc);
}
"""

const indeterminateComposition = newComposition """
const radius: f32 = 5.0;
fn compose() {
  let stroke = sdRoundedRectAt(uni.bounds, radius);
  let fill = sdRoundedRectAt(insetRect(uni.bounds, 1.0), radius - 1.0);
  drawShape(stroke, newGrayColor(0.78));
  let st = 20.0;
  let p = (vPos.x + vPos.y - uni.uPosition.x * st * 3.0) % st;
  let fc = gradient5(smoothstep(0.0, st, p),
    vec4f(0.88, 0.88, 0.88, 1.0),
    0.5, vec4f(0.32, 0.68, 0.95, 1.0),
    vec4f(0.88, 0.88, 0.88, 1.0));
  drawShape(fill, fc);
  var glossColor = gradient5(smoothstep(uni.bounds.y, uni.bounds.y + uni.bounds.w / 2.0, vPos.y),
    vec4f(1.0, 1.0, 1.0, 0.5),
    0.75, vec4f(1.0, 1.0, 1.0, 0.8),
    vec4f(1.0, 1.0, 1.0, 1.0));
  glossColor.a *= 0.65;
  var glossRect = uni.bounds;
  glossRect.w /= 2.0;
  blendShape(sdAnd(fill, sdRectAt(glossRect)), glossColor);
}
"""

method init(v: ProgressIndicator) =
  procCall v.View.init()
  v.animation = newAnimation()
  v.animation.finished = true
  v.animation.onAnimate = proc(p: float) =
    v.setNeedsDisplay()

method draw*(v: ProgressIndicator, r: Rect) =
  if v.mIndeterminate:
    indeterminateComposition.draw v.bounds:
      setUniform("uPosition", float32(epochTime() mod 1.0))
  else:
    piComposition.draw v.bounds:
      setUniform("uPosition", v.mValue)

proc `value=`*(v: ProgressIndicator, p: Coord) =
  v.mValue = p
  v.setNeedsDisplay()

proc value*(v: ProgressIndicator): Coord = v.mValue

proc indeterminate*(v: ProgressIndicator): bool = v.mIndeterminate
proc `indeterminate=`*(v: ProgressIndicator, flag: bool) =
  v.mIndeterminate = flag
  if v.animation.finished and flag and not v.window.isNil:
    v.window.addAnimation(v.animation)
  elif not flag:
    v.animation.cancel()

method viewWillMoveToWindow*(v: ProgressIndicator, w: Window) =
  if w.isNil:
    v.animation.cancel()
  elif v.mIndeterminate:
    w.addAnimation(v.animation)
