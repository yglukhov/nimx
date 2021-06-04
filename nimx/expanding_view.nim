import nimx/font
import nimx/button
import nimx/view
import nimx/context
import nimx/types
import nimx/color

import nimx/stack_view
import nimx/common/expand_button

const titleSize = 20.0
const expandButtonSize = 20.0

type ExpandingView* = ref object of View
    title*: string
    contentView*: View
    expanded*: bool
    hasOffset*: bool
    expandBut*: ExpandButton
    isDraggable*: bool
    isDragged: bool
    dragPoint: Point
    titleBarColor*: Color
    titleTextColor*: Color

    # initRect: Rect

proc updateFrame(v: ExpandingView) =
    var expandRect = v.contentView.frame
    if v.hasOffset:
        expandRect.size.width = expandRect.width + expandButtonSize

    expandRect.origin = v.frame.origin
    if v.expanded:
        expandRect.size.height = expandRect.height + titleSize
        v.setFrame(expandRect)
    else:
        expandRect.size.height = titleSize
        v.setFrame(newRect(v.frame.x, v.frame.y, expandRect.size.width, titleSize))

    if not v.superview.isNil:
        v.superview.subviewDidChangeDesiredSize(v, v.frame().size)

    if v.expanded:
        if v.contentView.superview.isNil:
            v.addSubview v.contentView
    elif not v.contentView.superview.isNil:
        v.contentView.removeFromSuperView()

proc init*(v: ExpandingView, w: Window, r: Rect, hasOffset: bool) =
    procCall v.View.init(w, r)
    v.backgroundColor = newColor(0.2, 0.2, 0.2, 1.0)
    v.title = "Expanded View"

    v.hasOffset = hasOffset
    if v.hasOffset:
        v.contentView = newStackView(w, newRect(expandButtonSize, titleSize, r.width - expandButtonSize, r.height - titleSize))
    else:
        v.contentView = newStackView(w, newRect(0, titleSize, r.width, r.height - titleSize))
    v.contentView.name = "contentView"
    v.contentView.resizingMask = "wb"
    v.addSubview(v.contentView)

    v.expandBut = newExpandButton(v, w, newRect(0.0, 0.0, expandButtonSize, expandButtonSize))
    v.expandBut.onExpandAction =  proc(state: bool) =
        v.expanded = state
        v.updateFrame()

    v.titleBarColor = titleBarColor()
    v.titleTextColor = titleTextColor()
    v.updateFrame()

proc expand*(v: ExpandingView) =
    v.expanded = true
    v.updateFrame()
    v.expandBut.expanded = true

proc newExpandingView*(w: Window, r: Rect, hasOffset: bool = false): ExpandingView =
    result.new()
    result.init(w, r, hasOffset)
    result.name = "expandingView"

method draw(v: ExpandingView, r: Rect) =
    template gfxCtx: untyped = v.window.gfxCtx
    template fontCtx: untyped = gfxCtx.fontCtx
    procCall v.View.draw(r)

    # title
    var titleRect: Rect
    titleRect.size.width = r.width
    titleRect.size.height = titleSize

    gfxCtx.fillColor = v.titleBarColor
    gfxCtx.drawRect(titleRect)

    gfxCtx.fillColor = v.titleTextColor
    gfxCtx.drawText(systemFontOfSize(fontCtx, 14.0), newPoint(25, 1), v.title)


    v.contentView.hidden = not v.expanded

proc addContent*(v: ExpandingView, subView: View) =
    v.contentView.addSubview(subView)
    v.updateFrame()

# method onTouchEv*(v: ExpandingView, e: var Event) : bool =
#     discard procCall v.View.onTouchEv(e)
#     result = true

method subviewDidChangeDesiredSize*(v: ExpandingView, sub: View, desiredSize: Size) =
    v.updateFrame()

method clipType*(v: ExpandingView): ClipType = ctDefaultClip
