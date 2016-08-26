import control
export control

import composition
import context
import font
import view_event_handling
import view_event_handling_new
import app
import property_visitor
import serializers

type SegmentedControl* = ref object of Control
    mSegments: seq[string]
    widths: seq[Coord]
    selectedSegmentOffset: Coord
    trackedSegmentOffset: Coord
    padding: Coord
    mSelectedSegment: int
    trackedSegment: int
    widthsValid: bool
    clickedSegmentRect: Rect
    clickedSegment: int

var scComposition = newComposition """
uniform vec4 uSelectedRect;
uniform vec4 uTrackedRect;

float radius = 5.0;

void compose() {
    vec4 strokeColor = newGrayColor(0.78);
    float stroke = sdRoundedRect(insetRect(bounds, 1.0), radius - 1.0);
    float fill = sdRoundedRect(insetRect(bounds, 2.0), radius - 2.0);
    drawInitialShape(stroke, strokeColor);
    drawShape(fill, vec4(1.0, 1, 1, 1));
    drawShape(sdAnd(sdRect(uTrackedRect), stroke), strokeColor);
    vec4 selectionColor = gradient(smoothstep(bounds.y, bounds.y + bounds.w, vPos.y),
        vec4(0.31, 0.60, 0.98, 1.0),
        vec4(0.09, 0.42, 0.88, 1.0));
    drawShape(sdAnd(sdRect(uSelectedRect), fill), selectionColor);
}
"""

proc `segments=`*(s: SegmentedControl, segs: seq[string]) =
    s.mSegments = segs
    s.widthsValid = false
    if s.mSelectedSegment >= segs.len: s.mSelectedSegment = segs.len - 1
    s.setNeedsDisplay()

template segments*(s: SegmentedControl): seq[string] = s.mSegments

method init*(s: SegmentedControl, r: Rect) =
    procCall s.Control.init(r)
    s.segments = @["hello", "world", "yo"]

proc recalculateSegmentWidths(s: SegmentedControl) =
    if s.widths.isNil:
        s.widths = newSeq[Coord](s.mSegments.len)
    else:
        s.widths.setLen(s.mSegments.len)

    let font = systemFont()
    var totalWidth = 0.Coord
    for i, seg in s.mSegments:
        let w = font.sizeOfString(seg).width
        s.widths[i] = w
        totalWidth += w
    s.padding = (s.bounds.width - totalWidth) / s.mSegments.len.Coord
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

    scComposition.draw s.bounds:
        if s.mSelectedSegment < s.widths.len and s.mSelectedSegment >= 0:
            setUniform("uSelectedRect",
                newRect(s.selectedSegmentOffset, 0, s.widths[s.mSelectedSegment] + s.padding, s.bounds.height))
            setUniform("uTrackedRect",
                newRect(s.trackedSegmentOffset, 0, s.widths[s.trackedSegment] + s.padding, s.bounds.height))
        else:
            setUniform("uSelectedRect", zeroRect)
            setUniform("uTrackedRect", zeroRect)

    let font = systemFont()
    let c = currentContext()
    var r = newRect(0, 0, 0, s.bounds.height)
    var strSize = newSize(0, font.height)
    c.strokeWidth = 0
    for i, w in s.widths:
        if i == s.mSelectedSegment:
            c.fillColor = whiteColor()
        else:
            c.fillColor = blackColor()
        r.size.width = w + s.padding
        strSize.width = w
        c.drawText(font, strSize.centerInRect(r), s.mSegments[i])
        if i != 0 and i != s.mSelectedSegment and i - 1 != s.mSelectedSegment and
                i != s.trackedSegment and i - 1 != s.trackedSegment:
            c.fillColor = newGrayColor(0.78)
            c.drawRect(newRect(r.origin.x - 1, 1, 1, r.height - 2))
        r.origin.x += r.size.width

template selectedSegment*(s: SegmentedControl): int = s.mSelectedSegment

proc `selectedSegment=`*(s: SegmentedControl, i: int) =
    s.mSelectedSegment = i
    if s.mSelectedSegment >= s.mSegments.len: s.mSelectedSegment = s.mSegments.len
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

method setBoundsSize*(v: SegmentedControl, s: Size) =
    procCall v.Control.setBoundsSize(s)
    v.widthsValid = false

method onTouchEv(s: SegmentedControl, e: var Event): bool =
    result = true
    case e.buttonState
    of bsDown:
        s.clickedSegment = -1
        s.clickedSegmentRect = ((0'f32,0'f32),(0'f32,0'f32))
        s.clickedSegment = s.segmentAtPoint(e.localPosition, s.clickedSegmentRect)
        if s.clickedSegment >= 0:
            s.trackedSegment = s.clickedSegment
            s.trackedSegmentOffset = s.clickedSegmentRect.x
            s.setNeedsDisplay()
    of bsUnknown:
        if e.localPosition.inRect(s.clickedSegmentRect):
            s.trackedSegment = s.clickedSegment
            s.trackedSegmentOffset = s.clickedSegmentRect.x
        else:
            s.trackedSegment = s.mSelectedSegment
            s.trackedSegmentOffset = s.selectedSegmentOffset
        s.setNeedsDisplay()
    of bsUp:
        if s.trackedSegment >= 0:
            s.mSelectedSegment = s.trackedSegment
            s.selectedSegmentOffset = s.trackedSegmentOffset
            s.setNeedsDisplay()
            s.sendAction(e)
        result = false

method visitProperties*(v: SegmentedControl, pv: var PropertyVisitor) =
    procCall v.Control.visitProperties(pv)
    pv.visitProperty("segments", v.segments)
    pv.visitProperty("selected", v.mSelectedSegment)

registerClass(SegmentedControl)
