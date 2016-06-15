import view
import context
export view

import clip_view
import scroll_bar

import event
import system_logger

type ScrollView* = ref object of View
    clipView: ClipView
    mHorizontalScrollBar, mVerticalScrollBar: ScrollBar

const scrollBarWidth = 16.Coord

proc onScrollBar(v: ScrollView, sb: ScrollBar)

proc relayout(v: ScrollView) =
    var cvs = v.bounds.size

    if not v.mVerticalScrollBar.isNil:
        cvs.width -= scrollBarWidth
    if not v.mHorizontalScrollBar.isNil:
        cvs.height -= scrollBarWidth
    if not v.clipView.isNil:
        v.clipView.setFrameSize(cvs)
    if not v.mVerticalScrollBar.isNil:
        v.mVerticalScrollBar.setFrameSize(newSize(v.mVerticalScrollBar.frame.width, cvs.height))
    if not v.mHorizontalScrollBar.isNil:
        v.mHorizontalScrollBar.setFrameSize(newSize(cvs.width, v.mHorizontalScrollBar.frame.height))

proc setScrollBar(v: ScrollView, vs: var ScrollBar, s: ScrollBar) =
    if not vs.isNil:
        vs.removeFromSuperview()
    let layoutChanged = (vs.isNil xor s.isNil)
    vs = s
    if not s.isNil:
        v.addSubview(s)
        s.onAction do(): v.onScrollBar(s)

    if layoutChanged:
        v.relayout()

proc `horizontalScrollBar=`*(v: ScrollView, s: ScrollBar) {.inline.} = v.setScrollBar(v.mHorizontalScrollBar, s)
proc `verticalScrollBar=`*(v: ScrollView, s: ScrollBar) {.inline.} = v.setScrollBar(v.mVerticalScrollBar, s)
template horizontalScrollBar*(v: ScrollView): ScrollBar = v.mHorizontalScrollBar
template verticalScrollBar*(v: ScrollView): ScrollBar = v.mVerticalScrollBar

proc newScrollView*(r: Rect): ScrollView =
    result.new()
    result.init(r)

    var sb = ScrollBar.new(newRect(0, r.height - scrollBarWidth, 0, scrollBarWidth))
    sb.autoresizingMask = {afFlexibleWidth, afFlexibleMinY}
    result.horizontalScrollBar = sb

    sb = ScrollBar.new(newRect(r.width - scrollBarWidth, 0, scrollBarWidth, 0))
    sb.autoresizingMask = {afFlexibleMinX, afFlexibleHeight}
    result.verticalScrollBar = sb

    result.clipView = newClipView(zeroRect)
    result.addSubview(result.clipView)
    result.relayout()

proc newScrollView*(v: View): ScrollView =
    # Create a scrollview by wrapping v into it
    result = newScrollView(v.frame)
    v.setFrameOrigin(zeroPoint)
    result.clipView.addSubview(v)
    result.autoresizingMask = v.autoresizingMask
    v.autoresizingMask = { afFlexibleMaxX, afFlexibleMaxY }

proc contentView*(v: ScrollView): View =
    if v.clipView.subviews.len > 0:
        result = v.clipView.subviews[0]

proc `contentView=`*(v: ScrollView, c: View) =
    if v.clipView.subviews.len > 0:
        v.clipView.subviews[0].removeFromSuperview()
    v.clipView.addSubview(c)

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

proc onScrollBar(v: ScrollView, sb: ScrollBar) =
    var contentSize = zeroSize
    let cv = v.contentView()
    if cv != nil:
        contentSize = cv.frame.size

    let cvBounds = v.clipView.bounds
    var o = cvBounds.origin

    if sb.isHorizontal:
        o.x = (contentSize.width - cvBounds.width) * sb.value
    else:
        o.y = (contentSize.height - cvBounds.height) * sb.value

    v.clipView.setBoundsOrigin(o)

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
