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


type StackView* = ref object of View

method init*(v: StackView, r: Rect) =
    procCall v.View.init(r)
    v.backgroundColor = contentViewColor()

proc recalculateContent(v: StackView)
proc newStackView*(r: Rect): StackView =
    result.new()
    result.init(r)
    result.recalculateContent()

method draw(v: StackView, r: Rect) =
    procCall v.View.draw(r)

proc recalculateContent(v: StackView) =
    var y = 0.0
    for sub in v.subviews:
        let frame = sub.frame
        if not sub.dragInProcess:
            sub.setFrameOrigin(newPoint(0, y))

        y = y + frame.size.height

    var myFrame = v.frame
    myFrame.size.height = y
    v.setFrame(myFrame)

method subviewDidChangeDesiredSize*(v: StackView, sub: View, desiredSize: Size) =
    v.recalculateContent()
    if not v.superview.isNil:
        v.superview.subviewDidChangeDesiredSize(v, v.frame().size)

method didAddSubview*(v: StackView, subView: View) =
    v.recalculateContent()

proc popupAtPoint*(ip: StackView, v: View, p: Point) =
    ip.removeFromSuperview()
    var origin: Point
    origin = v.convertPointToWindow(p)
    ip.setFrameOrigin(origin)
    v.window.addSubview(ip)
