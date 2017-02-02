import math

import nimx.font
import nimx.image
import nimx.button
import nimx.view
import nimx.event
import nimx.view_event_handling_new
import nimx.context
import nimx.types
import nimx.color

import nimx.stack_view
import nimx.common.expand_button

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

    if v.expanded:
        expandRect.size.height = expandRect.height + titleSize
        v.setFrame(expandRect)
    else:
        expandRect.size.height = titleSize
        v.setFrame(newRect(v.contentView.frame.x, v.contentView.frame.y, expandRect.size.width, titleSize))

    if not v.superview.isNil:
        v.superview.subviewDidChangeDesiredSize(v, v.frame().size)

    if v.expanded:
        if v.contentView.superview.isNil:
            v.addSubview v.contentView
    elif not v.contentView.superview.isNil:
        v.contentView.removeFromSuperView()

method init*(v: ExpandingView, r: Rect, hasOffset: bool) =
    procCall v.View.init(r)
    v.backgroundColor = newColor(0.2, 0.2, 0.2, 1.0)
    v.title = "Expanded View"

    v.hasOffset = hasOffset
    if v.hasOffset:
        v.contentView = newStackView(newRect(expandButtonSize, titleSize, r.width - expandButtonSize, r.height - titleSize))
    else:
        v.contentView = newStackView(newRect(0, titleSize, r.width, r.height - titleSize))
    v.contentView.resizingMask = "wb"
    v.addSubview(v.contentView)

    v.expandBut = newExpandButton(v, newRect(0.0, 0.0, expandButtonSize, expandButtonSize))
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

proc newExpandingView*(r: Rect, hasOffset: bool = false): ExpandingView =
    result.new()
    result.init(r, hasOffset)

method draw(v: ExpandingView, r: Rect) =
    procCall v.View.draw(r)

    # title
    let c = currentContext()
    let f = systemFontOfSize(14.0)
    var titleRect: Rect
    titleRect.size.width = r.width
    titleRect.size.height = titleSize

    c.fillColor = v.titleBarColor
    c.drawRect(titleRect)

    c.fillColor = v.titleTextColor
    c.drawText(f, newPoint(25, 1), v.title)


proc addContent*(v: ExpandingView, subView: View) =
    v.contentView.addSubview(subView)
    v.updateFrame()

proc startDrag(v: ExpandingView, e: Event) =
    v.isDragged = true
    v.dragPoint = v.frame.origin - e.position
    echo "start drag"

proc processDrag(v: ExpandingView, e: Event) =
    if v.isDragged:
        v.setFrameOrigin(e.position + v.dragPoint)

proc stopDrag(v: ExpandingView, e: Event) =
    if v.isDragged:
        let index = v.superview.subviews.find(v)
        let count = v.superview.subviews.len()
        for i in 0 .. count - 2:
            if v.frame.origin.y > v.superview.subviews[i].frame.origin.y and v.frame.origin.y < v.superview.subviews[i + 1].frame.origin.y:
                v.superview.insertSubview(v, i + 1)
                break

        if v.frame.origin.y < v.superview.subviews[0].frame.origin.y:
            v.superview.insertSubview(v, 0)
        elif v.frame.origin.y > v.superview.subviews[count - 1].frame.origin.y:
            v.superview.insertSubview(v, count)

        v.isDragged = false
        v.updateFrame()
        echo "stopDrag"

method onTouchEv*(v: ExpandingView, e: var Event) : bool =
    discard procCall v.View.onTouchEv(e)
    result = true

    # case e.buttonState
    # of bsDown:
    #     discard
    #     # echo e.position
    #     # if v.convertPointFromWindow(e.position).inRect(newRect(0.0, 0.0, v.bounds.width, titleSize)):
    #     #     v.startDrag(e)
    # of bsUnknown:
    #     v.processDrag(e)
    # of bsUp:
    #     v.stopDrag(e)
    # else:
    #     discard

method subviewDidChangeDesiredSize*(v: ExpandingView, sub: View, desiredSize: Size) =
    v.updateFrame()

method clipType*(v: ExpandingView): ClipType = ctDefaultClip
