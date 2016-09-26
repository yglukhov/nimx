import nimx.view
import nimx.context
import nimx.composition
import nimx.types
import nimx.event
import nimx.button
import math

type ExpandButton* = ref object of Button
    expanded*: bool
    onExpandAction*: proc(state: bool)

method init*(b: ExpandButton, r: Rect) =
    procCall b.Button.init(r)

    b.enable()
    b.onAction(proc(e: Event) =
        b.expanded = not b.expanded
        if not b.onExpandAction.isNil:
            b.onExpandAction(b.expanded)
        )

proc newExpandButton*(r: Rect): ExpandButton =
    result.new()
    result.init(r)

proc newExpandButton*(v: View, r: Rect): ExpandButton =
    result = newExpandButton(r)
    v.addSubview(result)

var disclosureTriangleComposition = newComposition """
uniform float uAngle;
void compose() {
    vec2 center = vec2(bounds.x + bounds.z / 2.0, bounds.y + bounds.w / 2.0 - 1.0);
    float triangle = sdRegularPolygon(center, 4.0, 3, uAngle);
    drawShape(triangle, vec4(0.9, 0.9, 0.9, 1));
}
"""

proc drawDisclosureTriangle(disclosed: bool, r: Rect) =
    disclosureTriangleComposition.draw r:
        setUniform("uAngle", if disclosed: Coord(PI / 2.0) else: Coord(0))
    discard

method draw*(b: ExpandButton, r: Rect) =
    drawDisclosureTriangle(b.expanded, r)