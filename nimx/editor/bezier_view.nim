import nimx / [ types, view, context, event, view_event_handling, gesture_detector, keyboard ]


type
    BezierView* = ref object of View
        pointOne: Point
        pointTwo: Point
        key: bool
        mOnAction: proc()

proc onAction*(v: BezierView, cb: proc())=
    v.mOnAction = cb

proc p1*(v: BezierView): float = v.pointOne.x / v.bounds.width

proc `p1=`*(v: BezierView, val: float)=
    v.pointOne.x = val * v.bounds.width

proc p2*(v: BezierView): float = (v.bounds.height - v.pointOne.y) / v.bounds.height

proc `p2=`*(v: BezierView, val: float)=
    v.pointOne.y = v.bounds.height - val * v.bounds.height

proc p3*(v: BezierView): float = v.pointTwo.x / v.bounds.width

proc `p3=`*(v: BezierView, val: float)=
    v.pointTwo.x = val * v.bounds.width

proc p4*(v: BezierView): float = (v.bounds.height - v.pointTwo.y) / v.bounds.width

proc `p4=`*(v: BezierView, val: float)=
    v.pointTwo.y = v.bounds.height - val * v.bounds.height

method onTouchEv*(v: BezierView, e: var Event): bool  =
    if e.buttonState == bsDown:
        v.key = e.keyCode == VirtualKey.MouseButtonPrimary

    else:
        var actionHappend: bool
        if v.key:
            actionHappend = v.pointOne != e.localPosition
            v.pointOne = e.localPosition
        else:
            actionHappend = v.pointTwo != e.localPosition
            v.pointTwo = e.localPosition

        if actionHappend and not v.mOnAction.isNil:
            v.mOnAction()

    v.window.setNeedsDisplay()

    result = true

method init*(v: BezierView, gfx: GraphicsContext, r: Rect)=
    procCall v.View.init(gfx, r)
    v.backgroundColor = newColor(0.7, 0.7, 0.7, 1.0)

method draw*(v: BezierView, r: Rect) =
    procCall v.View.draw(r)

    template c: untyped = v.gfx

    let botLeft = newPoint(0, v.bounds.height)
    let topRight = newPoint(v.bounds.width, 0.0)

    c.strokeWidth = 3
    c.strokeColor = newColor(0.0, 0.0, 0.0, 0.5)
    c.drawLine(botLeft, topRight)

    c.strokeWidth = 4
    c.strokeColor = blackColor()
    c.drawBezier(botLeft, v.pointOne, v.pointTwo, topRight)

    c.strokeWidth = 3
    c.strokeColor = newColor(0.8, 0.2, 0.2, 0.5)
    c.drawLine(botLeft, v.pointOne)

    c.strokeWidth = 3
    c.strokeColor = newColor(0.2, 0.8, 0.2, 0.5)
    c.drawLine(topRight, v.pointTwo)

