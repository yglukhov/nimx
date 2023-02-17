import kiwi

import nimx / [ view, window, cursor, view_event_handling, layout_vars ]
import view_dragging_listener

export view


type SplitView* = ref object of View
    constraints: seq[Constraint]
    separatorPositions: seq[Variable]
    mVertical: bool
    mResizable: bool
    hoveredDivider: int
    draggingDivider: int
    initialDragPos: Point

method init*(v: SplitView, r: Rect) =
    procCall v.View.init(r)
    v.hoveredDivider = -1
    v.draggingDivider = -1
    v.mResizable = true
    v.trackMouseOver(true)

# method updateLayout*(v: SplitView) =
#     echo "sv up: ", v.frame
#     for i, s in v.subviews:
#         echo "sv up[", i, "]: ", s.frame

#     for i, s in v.separatorPositions:
#         echo "sep[", i, "]: ", s.value

proc rebuildConstraints(v: SplitView) =
    let wnd = v.window
    if not wnd.isNil:
        for c in v.constraints:
            v.removeConstraint(c)

        let s = wnd.layoutSolver
        for vv in v.separatorPositions:
            s.removeEditVariable(vv)

    v.constraints.setLen(0)

    const minSeparatorGap = 30

    let numViews = v.subviews.len
    if numViews > 0:
        v.separatorPositions.setLen(numViews - 1)
        let s = wnd.layoutSolver
        var minPos = 400.0
        for i in 0 ..< numViews - 1:
            var p = v.separatorPositions[i]
            if p.isNil:
                if i > 0:
                    minPos += v.separatorPositions[i - 1].value
                p = newVariable(minPos)
                v.separatorPositions[i] = p
            s.addEditVariable(p, 50)
            s.suggestValue(p, p.value)

        if v.mVertical:
            # Vertical constraints
            v.constraints.add(v.layout.vars.top == v.subviews[0].layout.vars.top)
            v.constraints.add(v.layout.vars.bottom == v.subviews[^1].layout.vars.bottom)
            for i in 1 ..< numViews:
                v.constraints.add(v.subviews[i - 1].layout.vars.bottom == v.separatorPositions[i - 1] + v.layout.vars.top)
                v.constraints.add(v.subviews[i].layout.vars.top == v.subviews[i - 1].layout.vars.bottom)

            # Horizontal constraints
            for s in v.subviews:
                v.constraints.add(s.layout.vars.leading == v.layout.vars.leading)
                v.constraints.add(s.layout.vars.trailing == v.layout.vars.trailing)
                v.constraints.add(s.layout.vars.height >= minSeparatorGap)
        else:
            # Horizontal constraints
            v.constraints.add(v.layout.vars.leading == v.subviews[0].layout.vars.leading)
            v.constraints.add(v.layout.vars.trailing == v.subviews[^1].layout.vars.trailing)
            for i in 1 ..< numViews:
                v.constraints.add(v.subviews[i - 1].layout.vars.trailing == v.separatorPositions[i - 1] + v.layout.vars.leading)
                v.constraints.add(v.subviews[i].layout.vars.leading == v.subviews[i - 1].layout.vars.trailing)

            # Vertical constraints
            for s in v.subviews:
                v.constraints.add(s.layout.vars.top == v.layout.vars.top)
                v.constraints.add(s.layout.vars.bottom == v.layout.vars.bottom)
                v.constraints.add(s.layout.vars.width >= minSeparatorGap)

        for c in v.constraints:
            v.addConstraint(c)

method didAddSubview*(v: SplitView, s: View) =
    procCall v.View.didAddSubview(s)
    v.rebuildConstraints()

method didRemoveSubview*(v: SplitView, s: View) =
    procCall v.View.didRemoveSubview(s)
    v.rebuildConstraints()

proc dividerPosition*(v: SplitView, i: int): Coord =
    v.separatorPositions[i].value

proc setDividerPosition*(v: SplitView, pos: Coord, i: int) =
    v.window.layoutSolver.suggestValue(v.separatorPositions[i], pos)
    v.setNeedsDisplay()
    v.setNeedsLayout()

proc dividerPositions*(v: SplitView): seq[Coord] =
    let ln = v.subviews.len - 1
    result.setLen(ln)
    for i in 0 ..< ln:
        result[i] = v.dividerPosition(i)

proc `dividerPositions=`*(v: SplitView, pos: openarray[Coord]) =
    for i, p in pos: v.setDividerPosition(p, i)

proc `vertical=`*(v: SplitView, flag: bool) =
    if v.mVertical != flag:
        v.mVertical = flag
        v.rebuildConstraints()

proc vertical*(v: SplitView): bool {.inline.} = v.mVertical

proc `resizable=`*(v: SplitView, flag: bool) =
    v.mResizable = flag

proc resizable*(v: SplitView): bool {.inline.} = v.mResizable

proc dividerAtPoint(v: SplitView, p: Point): int =
    let p = v.convertPointToWindow(p)
    if v.mVertical:
        let top = v.layout.vars.top.value
        for i in 0 ..< v.subviews.len - 1:
            let sp = v.separatorPositions[i].value + top
            if p.y > sp - 5 and p.y < sp + 5:
                return i
    else:
        let leading = v.layout.vars.leading.value
        for i in 0 ..< v.subviews.len - 1:
            let sp = v.separatorPositions[i].value + leading
            if p.x > sp - 5 and p.x < sp + 5:
                return i

    result = -1

method onMouseOver*(v: SplitView, e: var Event) =
    if not v.resizable or v.draggingDivider != -1:
        return
    var nhv = v.dividerAtPoint(e.localPosition)
    if nhv == -1 and v.hoveredDivider != -1:
        newCursor(ckArrow).setCurrent()
    elif nhv != v.hoveredDivider:
        if v.mVertical:
            newCursor(ckSizeVertical).setCurrent()
        else:
            newCursor(ckSizeHorizontal).setCurrent()
    v.hoveredDivider = nhv

# TODO: We also need to reset the resizing mouse cursor onMouseOut.

method onTouchEv*(v: SplitView, e: var Event): bool =
    result = procCall v.View.onTouchEv(e)
    if not v.resizable or v.hoveredDivider == -1:
        return

    case e.buttonState
    of bsDown:
        discard
        v.initialDragPos = e.localPosition
        v.draggingDivider = v.hoveredDivider
    of bsUp, bsUnknown:
        if v.mVertical:
            v.setDividerPosition(e.localPosition.y, v.hoveredDivider)
        else:
            v.setDividerPosition(e.localPosition.x, v.hoveredDivider)
        if e.buttonState == bsUp:
            v.draggingDivider = -1
    result = true


method onInterceptTouchEv*(v: SplitView, e: var Event): bool =
    if v.hoveredDivider != -1:
        result = true

method replaceSubview*(v: SplitView, subviewIndex: int, withView: View) =
    let pos = v.dividerPositions
    procCall v.View.replaceSubview(subviewIndex, withView)
    v.dividerPositions = pos

registerClass(SplitView)
