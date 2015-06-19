import control
export control

import composition
import context
import font
import view_event_handling
import app

type SegmentedControl* = ref object of Control
    segments: seq[string]
    widths: seq[Coord]
    selectedSegmentOffset: Coord
    trackedSegmentOffset: Coord
    padding: Coord
    mSelectedSegment: int
    trackedSegment: int
    widthsValid: bool

var scComposition = newComposition """
uniform vec4 uSelectedRect;
uniform vec4 uTrackedRect;

float radius = 5.0;

void compose() {
    vec4 strokeColor = newGrayColor(0.78);
    float stroke = sdRoundedRect(bounds, radius);
    float fill = sdRoundedRect(insetRect(bounds, 1.0), radius - 1.0);
    drawShape(stroke, strokeColor);
    drawShape(fill, vec4(1.0, 1, 1, 1));

    drawShape(sdAnd(sdRect(uTrackedRect), stroke), strokeColor);

    vec4 selectionColor = gradient(smoothstep(bounds.y, bounds.y + bounds.w, vPos.y),
        vec4(0.31, 0.60, 0.98, 1.0),
        vec4(0.09, 0.42, 0.88, 1.0));
    drawShape(sdAnd(sdRect(uSelectedRect), fill), selectionColor);
}
"""

proc drawBecauseNimBug*(s: SegmentedControl, r: Rect) =
    scComposition.draw s.bounds:
        setUniform("uSelectedRect",
            newRect(s.selectedSegmentOffset, 0, s.widths[s.mSelectedSegment] + s.padding, s.bounds.height))
        setUniform("uTrackedRect",
            newRect(s.trackedSegmentOffset, 0, s.widths[s.trackedSegment] + s.padding, s.bounds.height))

proc recalculateSegmentWidths(s: SegmentedControl) =
    if s.widths.isNil:
        s.widths = newSeq[Coord](s.segments.len)
    else:
        s.widths.setLen(s.segments.len)

    let font = systemFont()
    var totalWidth = 0.Coord
    for i, seg in s.segments:
        let w = font.sizeOfString(seg).width
        s.widths[i] = w
        totalWidth += w
    s.padding = (s.bounds.width - totalWidth) / s.segments.len.Coord
    var xOff = 0.Coord
    for i, w in s.widths:
        let pw = w + s.padding
        if i == s.mSelectedSegment:
            s.selectedSegmentOffset = xOff
        if i == s.trackedSegment:
            s.trackedSegmentOffset = xOff
        xOff += pw
    s.widthsValid = true

method draw*(s: SegmentedControl, r: Rect) =
    if not s.widthsValid:
        s.recalculateSegmentWidths()
    s.drawBecauseNimBug(r)
    let font = systemFont()
    let c = currentContext()
    var r = newRect(0, 0, 0, s.bounds.height)
    var strSize = newSize(0, font.size)
    for i, w in s.widths:
        if i == s.mSelectedSegment:
            c.fillColor = whiteColor()
        else:
            c.fillColor = blackColor()
        r.size.width = w + s.padding
        strSize.width = w
        c.drawText(font, strSize.centerInRect(r), s.segments[i])
        if i != 0 and i != s.mSelectedSegment and i - 1 != s.mSelectedSegment and
                i != s.trackedSegment and i - 1 != s.trackedSegment:
            c.fillColor = newGrayColor(0.78)
            c.drawRect(newRect(r.origin.x - 1, 1, 1, r.height - 2))
        r.origin.x += r.size.width

proc `segments=`*(s: SegmentedControl, segs: seq[string]) =
    s.segments = segs
    s.widthsValid = false
    if s.mSelectedSegment >= segs.len: s.mSelectedSegment = segs.len
    s.setNeedsDisplay()

template selectedSegment*(s: SegmentedControl): int = s.mSelectedSegment

proc `selectedSegment=`*(s: SegmentedControl, i: int) =
    s.mSelectedSegment = i
    if s.mSelectedSegment >= s.segments.len: s.mSelectedSegment = s.segments.len
    s.widthsValid = false
    s.setNeedsDisplay()

proc segmentAtPoint(s: SegmentedControl, p: Point, r: var Rect): int =
    r.size.height = s.bounds.height
    for i, w in s.widths:
        r.size.width = w + s.padding
        if p.x < r.maxX:
            return i
        r.origin.x += r.size.width
    return -1

method onMouseDown(s: SegmentedControl, e: var Event): bool =
    result = true
    var clickedSegmentRect: Rect
    let clickedSegment = s.segmentAtPoint(e.localPosition, clickedSegmentRect)
    if clickedSegment >= 0:
        s.trackedSegment = clickedSegment
        s.trackedSegmentOffset = clickedSegmentRect.x
        s.setNeedsDisplay()

    mainApplication().pushEventFilter do(e: var Event, c: var EventFilterControl) -> bool:
        result = true
        if e.kind == etMouse:
            e.localPosition = s.convertPointFromWindow(e.position)
            if e.isButtonUpEvent():
                c = efcBreak
                result = s.onMouseUp(e)
            elif e.isMouseMoveEvent():
                if e.localPosition.inRect(clickedSegmentRect):
                    s.trackedSegment = clickedSegment
                    s.trackedSegmentOffset = clickedSegmentRect.x
                else:
                    s.trackedSegment = s.mSelectedSegment
                    s.trackedSegmentOffset = s.selectedSegmentOffset
                s.setNeedsDisplay()

method onMouseUp(s: SegmentedControl, e: var Event): bool =
    result = true
    if s.trackedSegment >= 0:
        s.mSelectedSegment = s.trackedSegment
        s.selectedSegmentOffset = s.trackedSegmentOffset
        s.setNeedsDisplay()
        s.sendAction(e)

method setBoundsSize*(v: SegmentedControl, s: Size) =
    procCall v.Control.setBoundsSize(s)
    v.widthsValid = false
