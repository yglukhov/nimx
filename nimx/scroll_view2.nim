import view, scroll_bar, event
import kiwi

import math

export view

type ScrollView* = ref object of View
    mContentView: View
    mHorizontalScrollBar, mVerticalScrollBar: ScrollBar
    xPos, yPos: Variable # Scroll positions
    mOnScrollCallback: proc()
    constraints: seq[Constraint]

const scrollBarWidth = 12.Coord

method init*(v: ScrollView, r: Rect) =
    procCall v.View.init(r)
    v.constraints = @[]
    v.xPos = newVariable()
    v.yPos = newVariable()
    v.addSubview(ScrollBar.new(newRect(0, 0, 10, 0)))
    v.addSubview(ScrollBar.new(newRect(0, 0, 0, 10)))

# proc onScrollBar(v: ScrollView, sb: ScrollBar)

proc onScroll*(v: ScrollView, cb:proc()) =
    v.mOnScrollCallback = cb

# proc scrollPosition*(v: ScrollView): Point=
#     #[
#         Result: Point where x and y between 0.0 .. 1.0
#      ]#
#     var cs = v.contentSize
#     result = newPoint(0.0, 0.0)
#     let csx = cs.width - v.clipView.bounds.width
#     let csy = cs.height - v.clipView.bounds.height
#     result.x = if csx > 0.0: v.clipView.bounds.x / csx else: 0
#     result.y = if csy > 0.0: v.clipView.bounds.y / csy else: 0

# proc recalcScrollbarKnobPositions(v: ScrollView) =
#     let sp = v.scrollPosition()
#     if not v.mHorizontalScrollBar.isNil:
#         v.mHorizontalScrollBar.value = sp.x
#     if not v.mVerticalScrollBar.isNil:
#         v.mVerticalScrollBar.value = sp.y

method onScroll*(v: ScrollView, e: var Event): bool =
    let s = v.window.layoutSolver
    s.suggestValue(v.xPos, v.xPos.value + e.offset.x * 10)
    s.suggestValue(v.yPos, v.yPos.value + e.offset.y * 10)

    v.setNeedsDisplay()
    v.setNeedsLayout()

    if not v.mOnScrollCallback.isNil:
        v.mOnScrollCallback()

    result = true

proc contentSize(v: ScrollView): Size =
    let cv = v.mContentView
    if not cv.isNil:
        result = cv.frame.size

method updateLayout*(v: ScrollView) =
    procCall v.View.updateLayout()
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

proc onScrollBar(v: ScrollView, sb: ScrollBar) =
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

proc rebuildConstraints(v: ScrollView) =
    for c in v.constraints:
        v.removeConstraint(c)

    v.constraints.setLen(0)

    let cv = v.mContentView
    if not cv.isNil:
        v.constraints.add(cv.layout.vars.left == v.xPos)
        v.constraints.add(cv.layout.vars.top == v.yPos)
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
    if s == v.mContentView: v.mContentView = nil
    elif s == v.mVerticalScrollBar: v.mVerticalScrollBar = nil
    elif s == v.mHorizontalScrollBar: v.mHorizontalScrollBar = nil
    v.rebuildConstraints()

method viewWillMoveToWindow*(v: ScrollView, w: Window) =
    procCall v.View.viewWillMoveToWindow(w)
    let wnd = v.window
    if not wnd.isNil:
        wnd.layoutSolver.removeEditVariable(v.xPos)
        wnd.layoutSolver.removeEditVariable(v.yPos)

method viewDidMoveToWindow*(v: ScrollView) =
    procCall v.View.viewDidMoveToWindow()
    let wnd = v.window
    if not wnd.isNil:
        wnd.layoutSolver.addEditVariable(v.xPos, WEAK)
        wnd.layoutSolver.addEditVariable(v.yPos, WEAK)

# proc scrollToRect*(v: ScrollView, r: Rect) =
#     ## If necessary scrolls to reveal the rect `r` which is in content bounds
#     ## coordinates.
#     let cvBounds = v.clipView.bounds
#     var o = cvBounds.origin
#     if o.x > r.x:
#         o.x = r.x
#     elif cvBounds.maxX < r.maxX:
#         o.x = r.maxX - cvBounds.width
#     if o.y > r.y:
#         o.y = r.y
#     elif cvBounds.maxY < r.maxY:
#         o.y = r.maxY - cvBounds.height

#     v.clipView.setBoundsOrigin(o)
#     v.recalcScrollbarKnobPositions()

# proc scrollToBottom*(v: ScrollView)=
#     let rect = newRect(0, v.contentSize.height - v.clipView.bounds.height, v.clipView.bounds.width, v.clipView.bounds.height)
#     v.scrollToRect(rect)

# proc scrollToTop*(v: ScrollView)=
#     v.scrollToRect(newRect(0, 0, v.clipView.bounds.width, v.clipView.bounds.height))

# proc scrollPageUp*(v: ScrollView)=
#     let cvBounds = v.clipView.bounds
#     var o = cvBounds.origin
#     if o.y > 0:
#         o.y = max(0, o.y - cvBounds.height)
#     let rect = newRect(o.x, o.y, cvBounds.width, cvBounds.height)
#     v.scrollToRect(rect)

# proc scrollPageDown*(v: ScrollView)=
#     let cvBounds = v.clipView.bounds
#     var o = cvBounds.origin
#     if o.y < cvBounds.maxY:
#         o.y = min(v.contentSize.height - cvBounds.height, o.y + cvBounds.height)
#     let rect = newRect(o.x, o.y, cvBounds.width, cvBounds.height)
#     v.scrollToRect(rect)

method clipType*(v: ScrollView): ClipType = ctDefaultClip
