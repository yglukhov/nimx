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
        needsDisplay*: bool

method init*(v: View, frame: Rect) =
    v.frame = frame
    v.bounds = newRect(0, 0, frame.width, frame.height)
    v.subviews = @[]
    v.autoresizingMask = { afFlexibleMaxX, afFlexibleMaxY }

proc new*[V](v: typedesc[V], frame: Rect): V =
    result.new()
    result.init(frame)

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

method viewWillMoveToSuperview*(v: View, s: View) = discard
method viewWillMoveToWindow*(v: View, w: Window) =
    for s in v.subviews:
        s.window = v.window
        s.viewWillMoveToWindow(w)

proc moveToWindow(v: View, w: Window) =
    v.window = w
    for s in v.subviews:
        s.moveToWindow(w)

template setNeedsDisplay*(v: View) =
    if v.window != nil:
        v.window.needsDisplay = true

proc removeSubview(v: View, s: View) =
    for i, ss in v.subviews:
        if ss == s:
            v.subviews.del(i)
            v.setNeedsDisplay()
            break

proc removeFromSuperview(v: View, callHandlers: bool) =
    if v.superview != nil:
        if callHandlers:
            if v.window != nil: v.viewWillMoveToWindow(nil)
            v.viewWillMoveToSuperview(nil)
        v.superview.removeSubview(v)
        v.moveToWindow(nil)
        v.superview = nil

method removeFromSuperview*(v: View) =
    v.removeFromSuperview(true)

method addSubview*(v: View, s: View) =
    if s.superview != v:
        if v.window != s.window: s.viewWillMoveToWindow(v.window)
        s.viewWillMoveToSuperview(v)
        s.removeFromSuperview(false)
        v.subviews.add(s)
        s.superview = v
        s.moveToWindow(v.window)
        v.setNeedsDisplay()

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

proc drawFocusRing*(v: View) =
    let c = currentContext()
    c.fillColor = clearColor()
    c.strokeColor = newColor(0.59, 0.76, 0.95, 0.9)
    c.strokeWidth = 3
    c.drawRoundedRect(v.bounds.inset(-1, -1), 2)

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
    v.setNeedsDisplay()
    v.resizeSubviews(oldSize)

method setBoundsOrigin*(v: View, o: Point) =
    v.bounds.origin = o
    v.setNeedsDisplay()

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

method viewShouldResignFirstResponder*(v, newFirstResponder: View): bool = true
method viewDidBecomeFirstResponder*(v: View) = discard

# Responder chain implementation
method makeFirstResponder*(v: View): bool =
    let w = v.window
    if not w.isNil:
        var shouldChange = true
        if not w.firstResponder.isNil:
            shouldChange = w.firstResponder.viewShouldResignFirstResponder(v)
        if shouldChange:
            w.firstResponder = v
            v.viewDidBecomeFirstResponder()
            result = true

proc isFirstResponder*(v: View): bool =
    if v.window != nil:
        result = v.window.firstResponder == v

proc isDescendantOf*(subView, superview: View): bool =
    var vi = subView
    while not vi.isNil:
        if vi == superview:
            return true
        vi = vi.superview
