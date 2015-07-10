import view
export view

import composition

type ProgressIndicator* = ref object of View
    mPosition: Coord

var piComposition = newComposition """
uniform float uPosition;

float radius = 5.0;

void compose() {
    float stroke = sdRoundedRect(bounds, radius);
    float fill = sdRoundedRect(insetRect(bounds, 1.0), radius - 1.0);
    drawShape(stroke, newGrayColor(0.78));
    drawShape(fill, newGrayColor(0.88));

    vec4 progressRect = bounds;
    progressRect.z *= uPosition;
    vec4 fc = gradient(smoothstep(bounds.y, bounds.y + bounds.w, vPos.y),
        vec4(0.71, 0.80, 0.88, 1.0),
        0.5, vec4(0.32, 0.68, 0.95, 1.0),
        vec4(0.71, 0.80, 0.88, 1.0));

    drawShape(sdAnd(fill, sdRect(progressRect)), fc);
}
"""

proc drawBecauseNimBug(v: ProgressIndicator, r: Rect) =
    piComposition.draw v.bounds:
        setUniform("uPosition", v.mPosition)

method draw*(v: ProgressIndicator, r: Rect) =
    v.drawBecauseNimBug(r)

proc `position=`*(v: ProgressIndicator, p: Coord) =
    v.mPosition = p
    v.setNeedsDisplay()

proc position*(v: ProgressIndicator): Coord = v.mPosition
