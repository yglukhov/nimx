import view, scroll_bar, event, layout_vars
import kiwi
import math
export view

import clip_view # [Deprecated old layout]

type ScrollView* = ref object of View
    mContentView: View
    clipView: ClipView # [Deprecated old layout]
    mHorizontalScrollBar, mVerticalScrollBar: ScrollBar
    mOnScrollCallback: proc()
    constraints: seq[Constraint]
    xPos, yPos: Variable # Scroll positions

const scrollBarWidth = 12.Coord

method init*(v: ScrollView, r: Rect) =
    procCall v.View.init(r)

    if v.usesNewLayout:
        # Assume new layout
        v.xPos = newVariable()
        v.yPos = newVariable()
        v.addSubview(ScrollBar.new(newRect(0, 0, 10, 0)))
        v.addSubview(ScrollBar.new(newRect(0, 0, 0, 10)))

proc onScrollBar(v: ScrollView, sb: ScrollBar)

proc onScroll*(v: ScrollView, cb: proc())=
    v.mOnScrollCallback = cb

proc relayout(v: ScrollView) = # [Deprecated old layout]
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

proc `horizontalScrollBar=`*(v: ScrollView, s: ScrollBar) =
    if v.usesNewLayout:
        v.addSubview(s)
    else:
        v.setScrollBar(v.mHorizontalScrollBar, s)

proc `verticalScrollBar=`*(v: ScrollView, s: ScrollBar) =
    if v.usesNewLayout:
        v.addSubview(s)
    else:
        v.setScrollBar(v.mVerticalScrollBar, s)

template horizontalScrollBar*(v: ScrollView): ScrollBar = v.mHorizontalScrollBar
template verticalScrollBar*(v: ScrollView): ScrollBar = v.mVerticalScrollBar

proc recalcScrollKnobSizes(v: ScrollView)

proc newScrollView*(r: Rect): ScrollView = # [Deprecated old layout]
    result.new()
    result.name = "scrollView"
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

proc contentView*(v: ScrollView): View =
    if v.usesNewLayout:
        result = v.mContentView
    else:
        if v.clipView.subviews.len > 0:
            result = v.clipView.subviews[0]

proc `contentView=`*(v: ScrollView, c: View) =
    if v.clipView.subviews.len > 0:
        v.clipView.subviews[0].removeFromSuperview()
    c.setFrameOrigin(zeroPoint)
    var sz = c.frame.size
    var changeFrame = false
    if afFlexibleWidth in c.autoresizingMask:
        sz.width = v.clipView.bounds.width
        changeFrame = true
    if afFlexibleHeight in c.autoresizingMask:
        sz.height = v.clipView.bounds.height
        changeFrame = true
    if changeFrame:
        c.removeFromSuperview()
        c.setFrameSize(sz)
    v.clipView.addSubview(c)
    v.recalcScrollKnobSizes()

proc newScrollView*(v: View): ScrollView = # [Deprecated old layout]
    # Create a scrollview by wrapping v into it
    result = newScrollView(v.frame)
    result.autoresizingMask = v.autoresizingMask
    result.contentView = v
    #v.autoresizingMask = { afFlexibleMaxX, afFlexibleMaxY }
    result.recalcScrollKnobSizes()

proc contentSize(v: ScrollView): Size =
    let cv = v.contentView
    if not cv.isNil:
        result = cv.frame.size

proc scrollPosition*(v: ScrollView): Point=
    ## Result: Point where x and y between 0.0 .. 1.0
    if v.usesNewLayout:
        doAssert(false, "Not implemented")
    else:
        var cs = v.contentSize
        result = newPoint(0.0, 0.0)
        let csx = cs.width - v.clipView.bounds.width
        let csy = cs.height - v.clipView.bounds.height
        result.x = if csx > 0.0: v.clipView.bounds.x / csx else: 0
        result.y = if csy > 0.0: v.clipView.bounds.y / csy else: 0

proc recalcScrollbarKnobPositions(v: ScrollView) =
    let sp = v.scrollPosition()
    if not v.mHorizontalScrollBar.isNil:
        v.mHorizontalScrollBar.value = sp.x
    if not v.mVerticalScrollBar.isNil:
        v.mVerticalScrollBar.value = sp.y

method updateLayout*(v: ScrollView) =
    procCall v.View.updateLayout()
    if v.usesNewLayout:
        let cs = v.contentSize
        let cvBounds = v.bounds.size
        if not v.mVerticalScrollBar.isNil:
            v.mVerticalScrollBar.knobSize = cvBounds.height / cs.height
            v.mVerticalScrollBar.value = (v.layout.vars.y.value - v.yPos.value) / (cs.height - cvBounds.height)
            v.mVerticalScrollBar.hidden = v.mVerticalScrollBar.knobSize == 1.0
        if not v.mHorizontalScrollBar.isNil:
            v.mHorizontalScrollBar.knobSize = cvBounds.width / cs.width
            v.mHorizontalScrollBar.value = (v.layout.vars.x.value - v.xPos.value) / (cs.width - cvBounds.width)
            v.mHorizontalScrollBar.hidden = v.mHorizontalScrollBar.knobSize == 1.0

method onScroll*(v: ScrollView, e: var Event): bool =
    if v.usesNewLayout:
        let s = v.window.layoutSolver
        s.suggestValue(v.xPos, v.xPos.value + e.offset.x * 10)
        s.suggestValue(v.yPos, v.yPos.value + e.offset.y * 10)

        v.setNeedsDisplay()
        v.setNeedsLayout()

        if not v.mOnScrollCallback.isNil:
            v.mOnScrollCallback()
    else:
        let cvBounds = v.clipView.bounds
        var o = cvBounds.origin
        o += e.offset

        let contentSize = v.contentSize

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
        v.recalcScrollbarKnobPositions()
        if not v.mOnScrollCallback.isNil:
            v.mOnScrollCallback()

    result = true

proc onScrollBar(v: ScrollView, sb: ScrollBar) =
    if v.usesNewLayout:
        let cs = v.contentSize
        let cvBounds = v.bounds.size
        let s = v.window.layoutSolver
        if sb.isHorizontal:
            let p = (cs.width - cvBounds.width) * sb.value
            s.suggestValue(v.xPos, v.layout.vars.x.value - p)
        else:
            let p = (cs.height - cvBounds.height) * sb.value
            s.suggestValue(v.yPos, v.layout.vars.y.value - p)

        v.setNeedsDisplay()
        v.setNeedsLayout()

        if not v.mOnScrollCallback.isNil:
            v.mOnScrollCallback()
    else:
        let contentSize = v.contentSize

        let cvBounds = v.clipView.bounds
        var o = cvBounds.origin

        if sb.isHorizontal:
            o.x = (contentSize.width - cvBounds.width) * sb.value
        else:
            o.y = (contentSize.height - cvBounds.height) * sb.value

        v.clipView.setBoundsOrigin(o)

method subviewDidChangeDesiredSize*(v: ScrollView, sub: View, desiredSize: Size) = # [Deprecated old layout]
    if not v.usesNewLayout:
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
        v.recalcScrollKnobSizes()
        v.recalcScrollbarKnobPositions()

proc recalcScrollKnobSizes(v: ScrollView) = # [Deprecated old layout]
    var cs = v.contentSize
    if not v.mHorizontalScrollBar.isNil and cs.width != 0.0:
        v.mHorizontalScrollBar.knobSize = v.bounds.width / cs.width
        v.mHorizontalScrollBar.hidden = v.mHorizontalScrollBar.knobSize == 1.0
    if not v.mVerticalScrollBar.isNil and cs.height != 0.0:
        v.mVerticalScrollBar.knobSize = v.bounds.height / cs.height
        v.mVerticalScrollBar.hidden = v.mVerticalScrollBar.knobSize == 1.0

method resizeSubviews*(v: ScrollView, oldSize: Size) = # [Deprecated old layout]
    procCall v.View.resizeSubviews(oldSize)
    if not v.usesNewLayout:
        v.recalcScrollKnobSizes()
        v.recalcScrollbarKnobPositions()

proc rebuildConstraints(v: ScrollView) =
    for c in v.constraints:
        v.removeConstraint(c)

    v.constraints.setLen(0)

    let cv = v.mContentView
    if not cv.isNil:
        v.constraints.add(cv.layout.vars.left == v.layout.vars.left + v.xPos)
        v.constraints.add(cv.layout.vars.top == v.layout.vars.top + v.yPos)
        v.constraints.add(cv.layout.vars.top <= v.layout.vars.top)
        v.constraints.add(cv.layout.vars.left <= v.layout.vars.left)
        var c = cv.layout.vars.bottom >= v.layout.vars.bottom
        c.strength = MEDIUM
        v.constraints.add(c)
        c = cv.layout.vars.right >= v.layout.vars.right
        c.strength = MEDIUM
        v.constraints.add(c)

    let hs = v.mHorizontalScrollBar
    if not hs.isNil:
        v.constraints.add(hs.layout.vars.left == v.layout.vars.left)
        v.constraints.add(hs.layout.vars.right == v.layout.vars.right - scrollBarWidth)
        v.constraints.add(hs.layout.vars.bottom == v.layout.vars.bottom)
        v.constraints.add(hs.layout.vars.height == scrollBarWidth)

    let vs = v.mVerticalScrollBar
    if not vs.isNil:
        v.constraints.add(vs.layout.vars.right == v.layout.vars.right)
        v.constraints.add(vs.layout.vars.top == v.layout.vars.top)
        v.constraints.add(vs.layout.vars.bottom == v.layout.vars.bottom - scrollBarWidth)
        v.constraints.add(vs.layout.vars.width == scrollBarWidth)

    for c in v.constraints:
        v.addConstraint(c)

method didAddSubview*(v: ScrollView, s: View) =
    procCall v.View.didAddSubview(s)
    if v.usesNewLayout:
        if s of ScrollBar:
            let sb = ScrollBar(s)
            if sb.isHorizontal:
                if not v.mHorizontalScrollBar.isNil:
                    v.mHorizontalScrollBar.removeFromSuperview()
                v.mHorizontalScrollBar = sb
            else:
                if not v.mVerticalScrollBar.isNil:
                    v.mVerticalScrollBar.removeFromSuperview()
                v.mVerticalScrollBar = sb
            sb.onAction do(): v.onScrollBar(sb)

        else:
            if not v.mContentView.isNil:
                v.mContentView.removeFromSuperview()
            v.mContentView = s

        # Make sure content view is the first one
        if not v.mContentView.isNil and v.subviews[0] != v.mContentView:
            let idx = v.subviews.find(v.mContentView)
            swap(v.subviews[0], v.subviews[idx])

        v.rebuildConstraints()

method didRemoveSubview*(v: ScrollView, s: View) =
    procCall v.View.didRemoveSubview(s)
    if v.usesNewLayout:
        if s == v.mContentView: v.mContentView = nil
        elif s == v.mVerticalScrollBar: v.mVerticalScrollBar = nil
        elif s == v.mHorizontalScrollBar: v.mHorizontalScrollBar = nil
        v.rebuildConstraints()

method viewWillMoveToWindow*(v: ScrollView, w: Window) =
    procCall v.View.viewWillMoveToWindow(w)
    if v.usesNewLayout:
        let wnd = v.window
        if not wnd.isNil:
            let s = wnd.layoutSolver
            s.removeEditVariable(v.xPos)
            s.removeEditVariable(v.yPos)

method viewDidMoveToWindow*(v: ScrollView) =
    procCall v.View.viewDidMoveToWindow()
    if v.usesNewLayout:
        let wnd = v.window
        if not wnd.isNil:
            let s = wnd.layoutSolver
            s.addEditVariable(v.xPos, WEAK)
            s.addEditVariable(v.yPos, WEAK)

proc scrollToRect*(v: ScrollView, r: Rect) =
    ## If necessary scrolls to reveal the rect `r` which is in content bounds
    ## coordinates.
    if v.usesNewLayout:
        echo "scrollToRect is not implemented with new layout"
        writeStackTrace()
    else:
        let cvBounds = v.clipView.bounds
        var o = cvBounds.origin
        if o.x > r.x:
            o.x = r.x
        elif cvBounds.maxX < r.maxX:
            o.x = r.maxX - cvBounds.width
        if o.y > r.y:
            o.y = r.y
        elif cvBounds.maxY < r.maxY:
            o.y = r.maxY - cvBounds.height

        v.clipView.setBoundsOrigin(o)
        v.recalcScrollbarKnobPositions()

proc scrollToBottom*(v: ScrollView)=
    doAssert(not v.usesNewLayout, "Not implemented")

    let rect = newRect(0, v.contentSize.height - v.clipView.bounds.height, v.clipView.bounds.width, v.clipView.bounds.height)
    v.scrollToRect(rect)

proc scrollToTop*(v: ScrollView)=
    doAssert(not v.usesNewLayout, "Not implemented")

    v.scrollToRect(newRect(0, 0, v.clipView.bounds.width, v.clipView.bounds.height))

proc scrollPageUp*(v: ScrollView)=
    doAssert(not v.usesNewLayout, "Not implemented")

    let cvBounds = v.clipView.bounds
    var o = cvBounds.origin
    if o.y > 0:
        o.y = max(0, o.y - cvBounds.height)
    let rect = newRect(o.x, o.y, cvBounds.width, cvBounds.height)
    v.scrollToRect(rect)

proc scrollPageDown*(v: ScrollView)=
    doAssert(not v.usesNewLayout, "Not implemented")

    let cvBounds = v.clipView.bounds
    var o = cvBounds.origin
    if o.y < cvBounds.maxY:
        o.y = min(v.contentSize.height - cvBounds.height, o.y + cvBounds.height)
    let rect = newRect(o.x, o.y, cvBounds.width, cvBounds.height)
    v.scrollToRect(rect)

method clipType*(v: ScrollView): ClipType =
    if v.usesNewLayout:
        ctDefaultClip
    else:
        ctNone

registerClass(ScrollView)
