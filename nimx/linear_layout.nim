import nimx.view
import view_dragging_listener

export view

type
    LinearLayout* = ref object of View
        mPadding: Coord
        mTopMargin: Coord
        mBottomMargin: Coord
        mRightMargin: Coord
        mLeftMargin: Coord
        mHorizontal: bool

proc newHorizontalLayout*(r: Rect): LinearLayout = LinearLayout.new(r)

proc newVerticalLayout*(r: Rect): LinearLayout =
    result = LinearLayout.new(r)
    result.mHorizontal = false

method init*(v: LinearLayout, r: Rect) =
    procCall v.View.init(r)
    v.mPadding = 1
    v.mHorizontal = true

proc `padding=`*(v: LinearLayout, p: Coord) =
    v.mPadding = p
    v.resizeSubviews(zeroSize)

template padding*(v: LinearLayout): Coord = v.mPadding

proc `topMargin=`*(v: LinearLayout, p: Coord) =
    v.mTopMargin = p
    v.resizeSubviews(zeroSize)

template topMargin*(v: LinearLayout): Coord = v.mTopMargin

proc `bottomMargin=`*(v: LinearLayout, p: Coord) =
    v.mBottomMargin = p
    v.resizeSubviews(zeroSize)

template bottomMargin*(v: LinearLayout): Coord = v.mBottomMargin

proc `leftMargin=`*(v: LinearLayout, p: Coord) =
    v.mLeftMargin = p
    v.resizeSubviews(zeroSize)

template leftMargin*(v: LinearLayout): Coord = v.mLeftMargin

proc `rightMargin=`*(v: LinearLayout, p: Coord) =
    v.mRightMargin = p
    v.resizeSubviews(zeroSize)

template rightMargin*(v: LinearLayout): Coord = v.mRightMargin

proc `horizontal=`*(v: LinearLayout, p: bool) =
    v.mHorizontal = p
    v.resizeSubviews(zeroSize)

template horizontal*(v: LinearLayout): bool = v.mHorizontal

proc canGrow(v: LinearLayout): bool =
    (v.mHorizontal and afFlexibleWidth notin v.autoresizingMask) or
        ((not v.mHorizontal) and afFlexibleHeight notin v.autoresizingMask)

method resizeSubviews*(v: LinearLayout, oldSize: Size) =
    let grows = v.canGrow()
    if v.mHorizontal:
        var f = newRect(v.mLeftMargin, v.mTopMargin,
            (v.bounds.width - (v.subviews.len - 1).Coord * v.mPadding) / v.subviews.len.Coord,
            v.bounds.height - v.mTopMargin - v.mBottomMargin)
        for s in v.subviews:
            if grows: f.size.width = s.frame.width
            s.setFrame(f)
            f.origin.x += f.width + v.mPadding
    else:
        var f = newRect(v.mLeftMargin, v.mTopMargin,
            v.bounds.width - v.mRightMargin - v.mLeftMargin,
            (v.bounds.height - (v.subviews.len - 1).Coord * v.mPadding) / v.subviews.len.Coord)
        for s in v.subviews:
            if grows: f.size.height = s.frame.height
            s.setFrame(f)
            f.origin.y += f.height + v.mPadding

proc updateSize*(v: LinearLayout) =
    # Better don't use this proc...
    var totalSize = v.frame.size
    if v.mHorizontal:
        totalSize.width = v.mRightMargin + v.mLeftMargin + v.mPadding * (v.subviews.len - 1).Coord
        for s in v.subviews: totalSize.width = totalSize.width + s.frame.width
    else:
        totalSize.height = v.mTopMargin + v.mBottomMargin + v.mPadding * (v.subviews.len - 1).Coord
        for s in v.subviews: totalSize.height = totalSize.height + s.frame.height
    v.setFrameSize(totalSize)
    if not v.superview.isNil:
        v.superview.subviewDidChangeDesiredSize(v, totalSize)

method addSubview*(v: LinearLayout, s: View) =
    procCall v.View.addSubview(s)
    if v.canGrow():
        v.updateSize()
    else:
        v.resizeSubviews(zeroSize)

method subviewDidChangeDesiredSize*(v: LinearLayout, sub: View, desiredSize: Size) =
    if v.canGrow():
        sub.setFrameSize(desiredSize)
        v.updateSize()
