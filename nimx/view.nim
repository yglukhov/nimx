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

type ClipType* = enum
    ctNone
    ctDefaultClip

type
    View* = ref object of RootObj
        window*: Window
        frame: Rect
        bounds: Rect
        subviews*: seq[View]
        superview*: View
        autoresizingMask*: set[AutoresizingFlag]
        backgroundColor*: Color

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


method viewDidChangeSuperview*(v: View) = discard
method viewDidChangeWindow*(v: View) =
    for s in v.subviews:
        s.window = v.window
        s.viewDidChangeWindow()

method removeSubview*(v: View, s: View) =
    for i, ss in v.subviews:
        if ss == s:
            v.subviews.del(i)
            break

method removeAllSubviews*(v: View) =
    for i in low(v.subviews)..high(v.subviews):
        v.subviews.del(i)

method removeFromSuperview*(v: View) =
    if v.superview != nil:
        v.superview.removeSubview(v)
        v.window = nil
        v.superview = nil

method addSubview*(v: View, s: View) =
    if s.superview != v:
        let oldWindow = s.window
        s.removeFromSuperview()
        v.subviews.add(s)
        s.superview = v
        s.window = v.window
        s.viewDidChangeSuperview()
        if s.window != oldWindow:
            s.viewDidChangeWindow()

method clipType*(v: View): ClipType = ctNone

proc recursiveDrawSubviews*(view: View)

proc drawWithinSuperview*(v: View) =
    # Assume current coordinate system is superview
    let c = currentContext()
    var tmpTransform = c.transform
    if v.bounds.size == v.frame.size:
        # Common case: bounds scale is 1.0
        # Simplify calculation
        tmpTransform.translate(newVector3(v.frame.x - v.bounds.x, v.frame.y - v.bounds.y))
    else:
        assert(false, "Not implemented")

    c.withTransform tmpTransform:
        if v.clipType() == ctDefaultClip:
            c.withClippingRect v.bounds:
                v.recursiveDrawSubviews()
        else:
            v.recursiveDrawSubviews()

method draw*(view: View, rect: Rect) =
    let c = currentContext()
    #c.fillColor = newGrayColor(0.93)
    c.fillColor = view.backgroundColor
    c.drawRect(view.bounds)

proc drawSubviews(view: View) {.inline.} =
    # Assume current coordinate system is view
    for i in view.subviews:
        i.drawWithinSuperview()

proc recursiveDrawSubviews*(view: View) =
    # Assume current coordinate system is view
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

method setBoundsSize*(v: View, s: Size) =
    let oldSize = v.bounds.size
    v.bounds.size = s
    v.resizeSubviews(oldSize)

method setBoundsOrigin*(v: View, o: Point) =
    v.bounds.origin = o

proc setBounds*(v: View, b: Rect) =
    v.setBoundsOrigin(b.origin)
    v.setBoundsSize(b.size)

method setFrameSize*(v: View, s: Size) =
    let oldSize = v.bounds.size
    v.frame.size = s
    v.setBoundsSize(s)

method setFrameOrigin*(v: View, o: Point) =
    v.frame.origin = o

method setFrame*(v: View, r: Rect) =
    if v.frame.origin != r.origin:
        v.setFrameOrigin(r.origin)
    if v.frame.size != r.size:
        v.setFrameSize(r.size)

method frame*(v: View): Rect = v.frame
method bounds*(v: View): Rect = v.bounds

method subviewDidChangeDesiredSize*(v: View, sub: View, desiredSize: Size) = discard

# Responder chain implementation
method makeFirstResponder*(v: View): bool =
    # TODO: Validate becoming a first responder
    if v.window != nil:
        v.window.firstResponder = v
        result = true

proc isFirstResponder*(v: View): bool =
    if v.window != nil:
        result = v.window.firstResponder == v

