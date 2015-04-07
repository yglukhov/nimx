import typetraits
import types
import context
import animation


export types

type AutoresizingFlag* = enum
    afFlexibleMinX
    afFlexibleMaxX
    afFlexibleMinY
    afFlexibleMaxY
    afFlexibleWidth
    afFlexibleHeight

type
    View* = ref object of RootObj
        window*: Window
        frame: Rect
        bounds: Rect
        subviews*: seq[View]
        superview: View
        autoresizingMask*: set[AutoresizingFlag]

    Window* = ref object of View
        firstResponder*: View
        animations*: seq[Animation]

method init*(v: View, frame: Rect) =
    v.frame = frame
    v.bounds = newRect(0, 0, frame.width, frame.height)
    v.subviews = @[]
    v.autoresizingMask = { afFlexibleMaxX, afFlexibleMaxY }

proc newView*(frame: Rect): View =
    result.new()
    result.init(frame)

proc convertPointToWindow*(v: View, p: Point): Point =
    var curV = v
    result = p
    while curV != v.window and not curV.isNil:
        result += curV.frame.origin
        curV = curV.superview

proc convertPointFromWindow*(v: View, p: Point): Point =
    var curV = v
    result = p
    while curV != v.window and not curV.isNil:
        result -= curV.frame.origin
        curV = curV.superview

proc convertRectoToWindow*(v: View, r: Rect): Rect =
    result.origin = v.convertPointToWindow(r.origin)
    # TODO: Respect bounds transformations
    result.size = r.size

proc convertRectFromWindow*(v: View, r: Rect): Rect =
    result.origin = v.convertPointFromWindow(r.origin)
    # TODO: Respect bounds transformations
    result.size = r.size

method removeSubview*(v: View, s: View) =
    for i, ss in v.subviews:
        if ss == s:
            v.subviews.del(i)
            break

method removeFromSuperview*(v: View) =
    if v.superview != nil:
        v.superview.removeSubview(v)
        v.window = nil
        v.superview = nil

method addSubview*(v: View, s: View) =
    if s.superview != v:
        s.removeFromSuperview()
        v.subviews.add(s)
        s.window = v.window
        s.superview = v

proc recursiveDrawSubviews*(view: View)

method draw*(view: View, rect: Rect) =
    let c = currentContext()
    c.fillColor = newGrayColor(0.93)
    c.drawRect(view.bounds)

proc drawSubviews(view: View) {.inline.} =
    let c = currentContext()
    for i in view.subviews:
        var tmpTransform = c.transform
        tmpTransform.translate(newVector3(i.frame.x, i.frame.y, 0))
        c.withTransform tmpTransform:
            i.recursiveDrawSubviews()

proc recursiveDrawSubviews*(view: View) =
    view.draw(view.bounds)
    view.drawSubviews()

method setFrame*(v: View, r: Rect)

method resizeSubviews*(v: View, oldSize: Size) =
    let sizeDiff = v.frame.size - oldSize

    for s in v.subviews:
        var newRect = s.frame
        if s.autoresizingMask.contains afFlexibleMinX:
            newRect.origin.x += sizeDiff.width
        elif s.autoresizingMask.contains afFlexibleWidth:
            newRect.size.width += sizeDiff.width

        if s.autoresizingMask.contains afFlexibleMinY:
            newRect.origin.y += sizeDiff.height
        elif s.autoresizingMask.contains afFlexibleHeight:
            newRect.size.height += sizeDiff.height

        s.setFrame(newRect)


method setFrameSize*(v: View, s: Size) =
    let oldSize = v.bounds.size
    v.frame.size = s
    v.bounds.size = s
    v.resizeSubviews(oldSize)

method setFrameOrigin*(v: View, o: Point) =
    v.frame.origin = o

method setFrame*(v: View, r: Rect) =
    if v.frame.origin != r.origin:
        v.setFrameOrigin(r.origin)
    if v.frame.size != r.size:
        v.setFrameSize(r.size)

method frame*(v: View): Rect = v.frame
method bounds*(v: View): Rect = v.bounds

# Responder chain implementation
method makeFirstResponder*(v: View): bool =
    # TODO: Validate becoming a first responder
    if v.window != nil:
        v.window.firstResponder = v
        result = true

proc isFirstResponder*(v: View): bool =
    if v.window != nil:
        result = v.window.firstResponder == v

