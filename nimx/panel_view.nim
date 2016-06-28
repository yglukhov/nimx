import math
import nimx.view
import nimx.app
import nimx.event
import nimx.view_event_handling_new
import nimx.context
import nimx.types
import nimx.composition
import nimx.gesture_detector_newtouch
import nimx.view
import view_dragging_listener

type PanelView* = ref object of View
    collapsible*: bool
    mCollapsed: bool
    contentHeight*: Coord

template titleHeight*(v: PanelView): Coord = Coord(27)

proc `collapsed=`*(v: PanelView, f: bool) =
    v.mCollapsed = f
    v.setFrameSize(newSize(v.frame.size.width, if v.mCollapsed: v.titleHeight else: v.titleHeight + v.contentHeight))
    v.setNeedsDisplay()

template collapsed*(v: PanelView): bool = v.mCollapsed

# PanelView implementation

method init*(v: PanelView, r: Rect) =
    procCall v.View.init(r)
    v.backgroundColor = newColor(0.5, 0.5, 0.5, 0.5)
    v.mCollapsed = false
    v.collapsible = false
    v.contentHeight = r.height - v.titleHeight

    v.enableDraggingByBackground()
    v.enableViewResizing()

    # Enable collapsibility
    v.addGestureDetector(newTapGestureDetector(proc(tapPoint: Point) =
        let innerPoint = tapPoint - v.frame.origin
        if innerPoint.x > 0 and innerPoint.x < v.titleHeight and innerPoint.y > 0 and innerPoint.y < v.titleHeight:
            if v.collapsible:
                v.collapsed = not v.collapsed
    ))

var disclosureTriangleComposition = newComposition """
uniform float uAngle;

void compose() {
    vec2 center = vec2(bounds.x + bounds.z / 2.0, bounds.y + bounds.w / 2.0 - 1.0);
    float triangle = sdRegularPolygon(center, 5.0, 3, uAngle);
    drawShape(triangle, vec4(0.7, 0.7, 0.7, 1));
}
"""

proc drawDisclosureTriangle(disclosed: bool, r: Rect) =
    disclosureTriangleComposition.draw r:
        setUniform("uAngle", if disclosed: Coord(PI / 2.0) else: Coord(0))

var gradientComposition = newComposition """
void compose() {
    vec4 color = gradient(
        smoothstep(bounds.y, 27.0, vPos.y),
        newGrayColor(0.5),
        newGrayColor(0.1)
    );
    drawShape(sdRoundedRect(bounds, 6.0), color);
}
"""

method draw(v: PanelView, r: Rect) =
    # Draws Panel View
    let c = currentContext()

    # Top label
    c.fillColor = newGrayColor(0.05, 0.8)
    c.strokeColor = newGrayColor(0.05, 0.8)

    c.drawRoundedRect(newRect(r.x, r.y, r.width, r.height), 6)

    if v.collapsible:
        if not v.collapsed:
            # Main panel
            c.fillColor = newGrayColor(0.4, 0.6)
            c.strokeColor = newGrayColor(0.4, 0.6)
            c.drawRect(newRect(r.x, r.y + v.titleHeight, r.width, r.height - v.titleHeight))

            # Collapse button open
            drawDisclosureTriangle(true, newRect(r.x, r.y, v.titleHeight, v.titleHeight))
        else:
            # Collapse button close
            drawDisclosureTriangle(false, newRect(r.x, r.y, v.titleHeight, v.titleHeight))

method clipType*(v: PanelView): ClipType = ctDefaultClip
