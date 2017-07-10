import math
import nimx.view
import nimx.app
import nimx.event
import nimx.view_event_handling_new
import nimx.context
import nimx.types
import nimx.composition
import nimx.gesture_detector
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
        var disclosureTriangleAngle: Coord
        if not v.collapsed:
            # Main panel
            c.fillColor = newGrayColor(0.4, 0.6)
            c.strokeColor = newGrayColor(0.4, 0.6)
            c.drawRect(newRect(r.x, r.y + v.titleHeight, r.width, r.height - v.titleHeight))
        else:
            disclosureTriangleAngle = Coord(PI / 2.0)

        c.fillColor = newColor(0.7, 0.7, 0.7)
        c.drawTriangle(newRect(r.x, r.y, v.titleHeight, v.titleHeight), disclosureTriangleAngle)

method clipType*(v: PanelView): ClipType = ctDefaultClip
