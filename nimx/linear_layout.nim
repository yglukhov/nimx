import nimx / [ view, cursor, view_event_handling, view_dragging_listener ]
export view

import nimx / meta_extensions / [ property_desc, visitors_gen, serializers_gen ]

type
    LinearLayout* = ref object of View
        mPadding: Coord
        mTopMargin: Coord
        mBottomMargin: Coord
        mRightMargin: Coord
        mLeftMargin: Coord
        mHorizontal: bool
        mUserResizeable: bool
        hoveredDivider: int
        initialDragPos: Point

proc newHorizontalLayout*(w: Window, r: Rect): LinearLayout =
    result = LinearLayout.new(w, r)
    result.name = "HorizontalLayout"

proc newVerticalLayout*(w: Window, r: Rect): LinearLayout =
    result = LinearLayout.new(w, r)
    result.name = "VerticalLayout"
    result.mHorizontal = false

method init*(v: LinearLayout, w: Window, r: Rect) =
    procCall v.View.init(w, r)
    v.mPadding = 1
    v.mHorizontal = true
    v.hoveredDivider = -1

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
    if v.mUserResizeable:
        # Spread size diff evenly across subviews
        var totalSize = 0.Coord
        let newViewSize = v.bounds.size
        if v.mHorizontal:
            for s in v.subviews: totalSize += s.frame.width
            let newTotalSize = newViewSize.width - v.mPadding * (v.subviews.len - 1).Coord - v.mLeftMargin - v.mRightMargin
            let k = newTotalSize / totalSize
            var x = v.mLeftMargin
            for s in v.subviews:
                let f = newRect(x, 0, s.frame.width * k, newViewSize.height)
                s.setFrame(f)
                x = f.maxX + v.mPadding
        else:
            for s in v.subviews: totalSize += s.frame.height
            let newTotalSize = newViewSize.height - v.mPadding * (v.subviews.len - 1).Coord - v.mTopMargin - v.mBottomMargin
            let k = newTotalSize / totalSize
            var y = v.mTopMargin
            for s in v.subviews:
                let f = newRect(0, y, newViewSize.width, s.frame.height * k)
                s.setFrame(f)
                y = f.maxY + v.mPadding
    else:
        # Resize subviews evenly
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

proc relayout(v: LinearLayout) =
    if v.canGrow():
        v.updateSize()
    else:
        v.resizeSubviews(zeroSize)

method didAddSubview*(v: LinearLayout, s: View) =
    procCall v.View.didAddSubview(s)
    v.relayout()

method didRemoveSubview*(v: LinearLayout, s: View) =
    procCall v.View.didRemoveSubview(s)
    v.relayout()

method subviewDidChangeDesiredSize*(v: LinearLayout, sub: View, desiredSize: Size) =
    if v.canGrow():
        sub.setFrameSize(desiredSize)
        v.updateSize()

proc `userResizeable=`*(v: LinearLayout, b: bool) =
    v.trackMouseOver(b)
    v.mUserResizeable = true

proc dividerPosition*(v: LinearLayout, i: int): Coord =
    let s = v.subviews[i]
    if v.mHorizontal:
        s.frame.maxX + v.mPadding / 2
    else:
        s.frame.maxY + v.mPadding / 2

proc setDividerPosition*(v: LinearLayout, pos: Coord, i: int) =
    let s1 = v.subviews[i]
    let s2 = v.subviews[i + 1]
    var f1 = s1.frame
    var f2 = s2.frame

    const minSize = 10
    if v.mHorizontal:
        var f1w = pos - f1.x - v.mPadding / 2
        var f2w = f2.maxX - pos - v.mPadding / 2
        if f1w < minSize:
            f1w = minSize
            f2w = f2.maxX - f1.x - f1w - v.mPadding
        elif f2w < minSize:
            f2w = minSize
            f1w = f2.maxX - f1.x - f2w - v.mPadding

        f1.size.width = f1w
        f2.origin.x = f2.maxX - f2w
        f2.size.width = f2w
        s1.setFrameSize(f1.size)
        s2.setFrame(f2)
    else:
        var f1h = pos - f1.y - v.mPadding / 2
        var f2h = f2.maxY - pos - v.mPadding / 2
        if f1h < minSize:
            f1h = minSize
            f2h = f2.maxY - f1.y - f1h - v.mPadding
        elif f2h < minSize:
            f2h = minSize
            f1h = f2.maxY - f1.y - f2h - v.mPadding

        f1.size.height = f1h
        f2.origin.y = f2.maxY - f2h
        f2.size.height = f2h
        s1.setFrameSize(f1.size)
        s2.setFrame(f2)

proc dividerPositions*(v: LinearLayout): seq[Coord] =
    if v.subviews.len == 0: return @[]
    let ln = v.subviews.len - 1
    result = newSeq[Coord](ln)
    for i in 0 ..< ln:
        result[i] = v.dividerPosition(i)

proc `dividerPositions=`*(v: LinearLayout, pos: openarray[Coord]) =
    for i, p in pos: v.setDividerPosition(p, i)

proc dividerAtPoint(v: LinearLayout, p: Point): int =
    if v.mHorizontal:
        for i in 0 ..< v.subviews.len - 1:
            let mx = v.subviews[i].frame.maxX
            if p.x > mx - 5 and p.x < mx + 5:
                return i
    else:
        for i in 0 ..< v.subviews.len - 1:
            let my = v.subviews[i].frame.maxY
            if p.y > my - 5 and p.y < my + 5:
                return i
    result = -1

method onMouseOver*(v: LinearLayout, e: var Event) =
    var nhv = v.dividerAtPoint(e.localPosition)
    if nhv == -1 and v.hoveredDivider != -1:
        newCursor(ckArrow).setCurrent()
    elif nhv != v.hoveredDivider:
        if v.mHorizontal:
            newCursor(ckSizeHorizontal).setCurrent()
        else:
            newCursor(ckSizeVertical).setCurrent()
    v.hoveredDivider = nhv

method onTouchEv*(v: LinearLayout, e: var Event): bool =
    result = procCall v.View.onTouchEv(e)
    if v.mUserResizeable and v.hoveredDivider != -1:
        result = true
        case e.buttonState
        of bsDown:
            discard
            v.initialDragPos = e.localPosition
        of bsUp, bsUnknown:
            if v.mHorizontal:
                v.setDividerPosition(e.localPosition.x, v.hoveredDivider)
            else:
                v.setDividerPosition(e.localPosition.y, v.hoveredDivider)

method onInterceptTouchEv*(v: LinearLayout, e: var Event): bool =
    if v.mUserResizeable and v.hoveredDivider != -1:
        result = true

method replaceSubview*(v: LinearLayout, subviewIndex: int, withView: View) =
    let pos = v.dividerPositions
    procCall v.View.replaceSubview(subviewIndex, withView)
    v.dividerPositions = pos

LinearLayout.properties:
    mPadding
    mTopMargin
    mBottomMargin
    mRightMargin
    mLeftMargin
    mHorizontal
    mUserResizeable
    hoveredDivider
    initialDragPos

registerClass(LinearLayout)
genVisitorCodeForView(LinearLayout)
genSerializeCodeForView(LinearLayout)
