import view
import context
export view

import clip_view

import event
import system_logger

type ScrollView* = ref object of View
    clipView: ClipView

proc newScrollView*(r: Rect): ScrollView =
    result.new()
    result.init(r)
    result.clipView = newClipView(result.bounds)
    result.addSubview(result.clipView)

proc newScrollView*(v: View): ScrollView =
    # Create a scrollview by wrapping v into it
    result = newScrollView(v.frame)
    v.setFrameOrigin(zeroPoint)
    result.clipView.addSubview(v)
    result.autoresizingMask = v.autoresizingMask
    v.autoresizingMask = { afFlexibleMaxX, afFlexibleMaxY }

proc contentView(v: ScrollView): View =
    if v.clipView.subviews.len > 0:
        result = v.clipView.subviews[0]

method onScroll*(v: ScrollView, e: var Event): bool =
    let cvBounds = v.clipView.bounds
    var o = cvBounds.origin
    o += e.offset

    var contentSize = zeroSize
    let cv = v.contentView()
    if cv != nil:
        contentSize = cv.frame.size

    # Trim x
    if contentSize.width - o.x < cvBounds.width:
        o.x = contentSize.width - cvBounds.width
    if o.x < 0:
        o.x = 0

    # Trim y
    if contentSize.height - o.y < cvBounds.height:
        o.y = contentSize.height - cvBounds.height
    if o.y < 0:
        o.y = 0

    v.clipView.setBoundsOrigin(o)
    result = true

method subviewDidChangeDesiredSize*(v: ScrollView, sub: View, desiredSize: Size) =
    let cvBounds = v.clipView.bounds
    var boundsOrigin = cvBounds.origin
    var size = desiredSize
    if desiredSize.width < cvBounds.width:
        size.width = cvBounds.width
        boundsOrigin.x = 0
    if desiredSize.height < cvBounds.height:
        size.height = cvBounds.height
        boundsOrigin.y = 0

    v.clipView.setBoundsOrigin(boundsOrigin)
    v.contentView().setFrameSize(size)
