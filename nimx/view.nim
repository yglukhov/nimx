import typetraits, tables, sequtils
import types
import context
import animation
import animation_runner
import property_visitor
import class_registry
import serializers
import kiwi
import notification_center

export types
export animation_runner, class_registry

const NimxFristResponderChangedInWindow* = "NimxFristResponderChangedInWindow"

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
    GestureDetector* = ref object of RootObj

    DragDestinationDelegate* = ref object of RootObj

    LayoutInfo = object
        vars*: ViewLayoutVars
        constraintPrototypes: seq[Constraint]
        constraints: seq[Constraint]

    View* = ref object of RootObj
        window*: Window
        name*: string
        frame: Rect                 ## view rect in superview coordinate system
        bounds: Rect                ## view rect in its own coordinate system, starting from 0,0
        subviews*: seq[View]
        superview*: View
        autoresizingMask*: set[AutoresizingFlag]
        backgroundColor*: Color
        gestureDetectors*: seq[GestureDetector]
        touchTarget*: View
        interceptEvents*: bool      ## when view starts to handle tap, this flag set to true
        mouseInside*: bool
        handleMouseOver: bool
        hidden*: bool
        dragDestination*: DragDestinationDelegate
        layout*: LayoutInfo

    Window* = ref object of View
        firstResponder*: View       ## handler of untargeted (keyboard and menu) input
        animationRunners*: seq[AnimationRunner]
        needsDisplay*: bool
        needsLayout*: bool
        mouseOverListeners*: seq[View]
        pixelRatio*: float32
        mActiveBgColor*: Color
        layoutSolver*: Solver
        onClose*: proc()
        mCurrentTouches*: TableRef[int, View]

    ViewLayoutVars = object
        x*, y*, width*, height*: Variable

proc centerX*(phs: ViewLayoutVars): Expression = phs.x + phs.width / 2
proc centerY*(phs: ViewLayoutVars): Expression = phs.y + phs.height / 2

proc left*(phs: ViewLayoutVars): Variable {.inline.} = phs.x
proc right*(phs: ViewLayoutVars): Expression {.inline.} = phs.x + phs.width

proc top*(phs: ViewLayoutVars): Variable {.inline.} = phs.y
proc bottom*(phs: ViewLayoutVars): Expression = phs.y + phs.height

const leftToRight = true

proc leading*(phs: ViewLayoutVars): Expression =
    if leftToRight: newExpression(newTerm(phs.left)) else: -phs.right

proc trailing*(phs: ViewLayoutVars): Expression =
    if leftToRight: phs.right else: -newExpression(newTerm(phs.left))

proc origin*(phs: ViewLayoutVars): array[2, Expression] = [newExpression(newTerm(phs.x)), newExpression(newTerm(phs.y))]
proc center*(phs: ViewLayoutVars): array[2, Expression] = [phs.centerX, phs.centerY]
proc size*(phs: ViewLayoutVars): array[2, Expression] = [newExpression(newTerm(phs.width)), newExpression(newTerm(phs.height))]

var prevPHS*, nextPHS*, superPHS*, selfPHS*: ViewLayoutVars

proc init(phs: var ViewLayoutVars) =
    phs.x = newVariable("x", 0)
    phs.y = newVariable("y", 0)
    phs.width = newVariable("width", 0)
    phs.height = newVariable("height", 0)

init(prevPHS)
init(nextPHS)
init(superPHS)
init(selfPHS)

proc init(i: var LayoutInfo) =
    i.vars.init()
    i.constraintPrototypes = @[]
    i.constraints = @[]

proc replacePlaceholderVar(view: View, indexOfViewInSuper: int, v: var Variable) =
    var prevView, nextView: View
    if indexOfViewInSuper != 0:
        prevView = view.superview.subviews[indexOfViewInSuper - 1]
    if indexOfViewInSuper < view.superview.subviews.len - 1:
        nextView = view.superview.subviews[indexOfViewInSuper + 1]

    if system.`==`(v, prevPHS.x):
        doAssert(not prevView.isNil, "Cannot resolve prev, view is is the first child")
        v = prevView.layout.vars.x
    elif system.`==`(v, prevPHS.y):
        doAssert(not prevView.isNil, "Cannot resolve prev, view is is the first child")
        v = prevView.layout.vars.y
    elif system.`==`(v, prevPHS.width):
        doAssert(not prevView.isNil, "Cannot resolve prev, view is is the first child")
        v = prevView.layout.vars.width
    elif system.`==`(v, prevPHS.height):
        doAssert(not prevView.isNil, "Cannot resolve prev, view is is the first child")
        v = prevView.layout.vars.height
    elif system.`==`(v, nextPHS.x):
        doAssert(not nextView.isNil, "Cannot resolve next, view is is the last child")
        v = nextView.layout.vars.x
    elif system.`==`(v, nextPHS.y):
        doAssert(not nextView.isNil, "Cannot resolve next, view is is the last child")
        v = nextView.layout.vars.y
    elif system.`==`(v, nextPHS.width):
        doAssert(not nextView.isNil, "Cannot resolve next, view is is the last child")
        v = nextView.layout.vars.width
    elif system.`==`(v, nextPHS.height):
        doAssert(not nextView.isNil, "Cannot resolve next, view is is the last child")
        v = nextView.layout.vars.height
    elif system.`==`(v, superPHS.x):
        v = view.superview.layout.vars.x
    elif system.`==`(v, superPHS.y):
        v = view.superview.layout.vars.y
    elif system.`==`(v, superPHS.width):
        v = view.superview.layout.vars.width
    elif system.`==`(v, superPHS.height):
        v = view.superview.layout.vars.height
    elif system.`==`(v, selfPHS.x):
        v = view.layout.vars.x
    elif system.`==`(v, selfPHS.y):
        v = view.layout.vars.y
    elif system.`==`(v, selfPHS.width):
        v = view.layout.vars.width
    elif system.`==`(v, selfPHS.height):
        v = view.layout.vars.height

proc instantiateConstraint(v: View, c: Constraint) =
    # Instantiate constrinat prototype and add it to the window
    let ic = newConstraint(c.expression, c.op, c.strength)
    let indexOfViewInSuper = v.superview.subviews.find(v)
    assert(indexOfViewInSuper != -1)
    let count = ic.expression.terms.len
    for i in 0 ..< count:
        replacePlaceholderVar(v, indexOfViewInSuper, ic.expression.terms[i].variable)

    v.layout.constraints.add(ic)

    assert(not v.window.isNil, "Internal error")
    v.window.layoutSolver.addConstraint(ic)

proc addConstraint*(v: View, c: Constraint) =
    v.layout.constraintPrototypes.add(c)
    if not v.window.isNil:
        v.instantiateConstraint(c)

proc removeConstraint*(v: View, c: Constraint) =
    let idx = v.layout.constraintPrototypes.find(c)
    assert(idx != -1)
    v.layout.constraintPrototypes.del(idx)
    if not v.window.isNil:
        v.window.layoutSolver.removeConstraint(v.layout.constraints[idx])
        v.layout.constraints.del(idx)
        assert(v.layout.constraintPrototypes.len == v.layout.constraints.len)

method init*(v: View, frame: Rect) {.base.} =
    v.frame = frame
    v.layout.init()
    v.bounds = newRect(0, 0, frame.width, frame.height)
    v.subviews = @[]
    v.gestureDetectors = @[]
    v.autoresizingMask = { afFlexibleMaxX, afFlexibleMaxY }

proc addMouseOverListener(w: Window, v: View) =
    let i = w.mouseOverListeners.find(v)
    if i == -1: w.mouseOverListeners.add(v)

proc removeMouseOverListener(w: Window, v: View) =
    let i = w.mouseOverListeners.find(v)
    if i != -1: w.mouseOverListeners.del(i)

proc trackMouseOver*(v: View, val: bool) =
    v.handleMouseOver = val
    if not v.window.isNil:
        if val:
            v.window.addMouseOverListener(v)
        else:
            v.window.removeMouseOverListener(v)


proc addGestureDetector*(v: View, d: GestureDetector) = v.gestureDetectors.add(d)

proc removeGestureDetector*(v: View, d: GestureDetector) =
    var index = 0
    while index < v.gestureDetectors.len:
        if v.gestureDetectors[index] == d:
            v.gestureDetectors.delete(index)
            break
        else:
            inc index

proc removeAllGestureDetectors*(v: View) = v.gestureDetectors.setLen(0)

proc new*[V](v: typedesc[V], frame: Rect): V = # Deprecated
    result.new()
    result.init(frame)

proc newView*(frame: Rect): View = # Deprecated
    result.new()
    result.init(frame)

method convertPointToParent*(v: View, p: Point): Point {.base.} = p + v.frame.origin - v.bounds.origin
method convertPointFromParent*(v: View, p: Point): Point {.base.} = p - v.frame.origin + v.bounds.origin

proc convertPointToWindow*(v: View, p: Point): Point =
    var curV = v
    result = p
    while curV != v.window and not curV.isNil:
        result = curV.convertPointToParent(result)
        curV = curV.superview

proc convertPointFromWindow*(v: View, p: Point): Point =
    if v == v.window: p
    else: v.convertPointFromParent(v.superview.convertPointFromWindow(p))

proc convertRectToWindow*(v: View, r: Rect): Rect =
    result.origin = v.convertPointToWindow(r.origin)
    # TODO: Respect bounds transformations
    result.size = r.size

proc convertRectFromWindow*(v: View, r: Rect): Rect =
    result.origin = v.convertPointFromWindow(r.origin)
    # TODO: Respect bounds transformations
    result.size = r.size

# Responder chain implementation
method acceptsFirstResponder*(v: View): bool {.base.} = false
method viewShouldResignFirstResponder*(v, newFirstResponder: View): bool {.base.} = true
method viewDidBecomeFirstResponder*(v: View) {.base.} = discard

proc makeFirstResponder*(w: Window, responder: View): bool =
    var shouldChange = true
    let r = if responder.isNil: w else: responder
    if not w.firstResponder.isNil:
        shouldChange = w.firstResponder.viewShouldResignFirstResponder(r)
    if shouldChange:
        w.firstResponder = r
        r.viewDidBecomeFirstResponder()
        sharedNotificationCenter().postNotification(NimxFristResponderChangedInWindow, newVariant(r))
        result = true

method makeFirstResponder*(v: View): bool {.base.} =
    let w = v.window
    if not w.isNil:
        result = w.makeFirstResponder(v)

template isFirstResponder*(v: View): bool =
    not v.window.isNil and v.window.firstResponder == v

####
method viewWillMoveToSuperview*(v: View, s: View) {.base.} = discard
method viewWillMoveToWindow*(v: View, w: Window) {.base.} =
    if not v.window.isNil:
        v.window.removeMouseOverListener(v)
        if v.window.firstResponder == v and w != v.window:
            discard v.window.makeFirstResponder(nil)

        for c in v.layout.constraints:
            v.window.layoutSolver.removeConstraint(c)
        v.layout.constraints.setLen(0)

    assert(v.layout.constraints.len == 0)

    if not w.isNil:
        if v.handleMouseOver:
            w.addMouseOverListener(v)

    for s in v.subviews:
        s.window = v.window
        s.viewWillMoveToWindow(w)

method viewDidMoveToWindow*(v: View){.base.} =
    if not v.window.isNil:
        for c in v.layout.constraintPrototypes:
            v.instantiateConstraint(c)

    for s in v.subviews:
        s.viewDidMoveToWindow()

proc moveToWindow(v: View, w: Window) =
    v.window = w
    for s in v.subviews:
        s.moveToWindow(w)

method markNeedsDisplay*(w: Window) {.base.} =
    # Should not be called directly
    discard

template setNeedsDisplay*(v: View) =
    let w = v.window
    if not w.isNil:
        if not w.needsDisplay:
            w.needsDisplay = true
            w.markNeedsDisplay()

template setNeedsLayout*(v: View) =
    let w = v.window
    if not w.isNil:
        w.needsLayout = true

method didAddSubview*(v, s: View) {.base.} = discard
method didRemoveSubview*(v, s: View) {.base.} = discard

proc removeSubview(v: View, s: View) =
    let i = v.subviews.find(s)
    if i != -1:
        v.subviews.delete(i)
        v.didRemoveSubview(s)
        v.setNeedsDisplay()
        v.setNeedsLayout()

proc removeFromSuperview(v: View, callHandlers: bool) =
    if v.superview != nil:
        if callHandlers:
            if v.window != nil: v.viewWillMoveToWindow(nil)
            v.viewWillMoveToSuperview(nil)
        v.superview.removeSubview(v)
        v.moveToWindow(nil)
        v.viewDidMoveToWindow()
        v.superview = nil

method removeFromSuperview*(v: View) {.base.} =
    v.removeFromSuperview(true)

proc removeAllSubviews*(v: View)=
    while v.subviews.len > 0:
        v.subviews[0].removeFromSuperview()

proc insertSubview*(v, s: View, i: int) =
    if s.superview != v:
        if v.window != s.window: s.viewWillMoveToWindow(v.window)
        s.viewWillMoveToSuperview(v)
        s.removeFromSuperview(false)
        v.subviews.insert(s, i)
        s.superview = v
        s.moveToWindow(v.window)
        s.viewDidMoveToWindow()
        v.didAddSubview(s)
    else:
        var index = v.subviews.find(s)
        if index < 0 or i == index:
            return

        v.subviews.delete(index)
        if i < index:
            v.subviews.insert(s, i)
        elif i > index:
            v.subviews.insert(s, i - 1)

        s.superview = v
    v.setNeedsDisplay()
    v.setNeedsLayout()

proc insertSubviewAfter*(v, s, a: View) = v.insertSubview(s, v.subviews.find(a) + 1)
proc insertSubviewBefore*(v, s, a: View) = v.insertSubview(s, v.subviews.find(a))
proc addSubview*(v: View, s: View) = v.insertSubview(s, v.subviews.len)

method replaceSubview*(v, s, withView: View) {.base.} =
    assert(s.superview == v)
    let i = v.subviews.find(s)
    s.removeFromSuperview()
    v.insertSubview(withView, i)

method clipType*(v: View): ClipType {.base.} = ctNone

proc recursiveDrawSubviews*(view: View)

proc drawWithinSuperview*(v: View) =
    # Assume current coordinate system is superview
    if v.hidden: return

    let c = currentContext()
    var tmpTransform = c.transform
    if v.bounds.size == v.frame.size:
        # Common case: bounds scale is 1.0
        # Simplify calculation
        tmpTransform.translate(newVector3(v.frame.x - v.bounds.x, v.frame.y - v.bounds.y))
    else:
        echo "bounds: ", v.bounds
        echo "frame: ", v.frame
        assert(false, "Not implemented")

    c.withTransform tmpTransform:
        if v.clipType() == ctDefaultClip:
            c.withClippingRect v.bounds:
                v.recursiveDrawSubviews()
        else:
            v.recursiveDrawSubviews()

method draw*(view: View, rect: Rect) {.base.} =
    let c = currentContext()
    if view.backgroundColor.a > 0.001:
        c.fillColor = view.backgroundColor
        c.strokeWidth = 0
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

method setFrame*(v: View, r: Rect) {.base.} # Deprecated

method resizeSubviews*(v: View, oldSize: Size) {.base.} = # Deprecated
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

method updateLayout*(v: View) {.base.} = discard

proc recursiveUpdateLayout*(v: View, relPoint: Point) =
    v.frame.origin.x = v.layout.vars.x.value - relPoint.x
    v.frame.origin.y = v.layout.vars.y.value - relPoint.y
    v.frame.size.width = v.layout.vars.width.value
    v.frame.size.height = v.layout.vars.height.value
    v.bounds.size = v.frame.size
    v.updateLayout()
    let relPoint = newPoint(v.layout.vars.x.value, v.layout.vars.y.value)
    for s in v.subviews:
        s.recursiveUpdateLayout(relPoint)

method setBoundsSize*(v: View, s: Size) {.base.} = # Deprecated
    let oldSize = v.bounds.size
    v.bounds.size = s
    v.setNeedsDisplay()
    v.resizeSubviews(oldSize)

method setBoundsOrigin*(v: View, o: Point) {.base.} = # Deprecated
    v.bounds.origin = o
    v.setNeedsDisplay()

proc setBounds*(v: View, b: Rect) = # Deprecated
    v.setBoundsOrigin(b.origin)
    v.setBoundsSize(b.size)

method setFrameSize*(v: View, s: Size) {.base.} = # Deprecated
    v.frame.size = s
    v.setBoundsSize(s)

method setFrameOrigin*(v: View, o: Point) {.base.} = # Deprecated
    v.frame.origin = o
    v.setNeedsDisplay()

method setFrame*(v: View, r: Rect) = # Deprecated
    if v.frame.origin != r.origin:
        v.setFrameOrigin(r.origin)
    if v.frame.size != r.size:
        v.setFrameSize(r.size)

method frame*(v: View): Rect {.base.} = v.frame
method bounds*(v: View): Rect {.base.} = v.bounds

method subviewDidChangeDesiredSize*(v: View, sub: View, desiredSize: Size) {.base.} = discard # Deprecated

proc autoresizingMaskFromStrLit(s: string): set[AutoresizingFlag] {.compileTime.} = # Deprecated
    case s[0]
    of 'w': result.incl(afFlexibleWidth)
    of 'l': result.incl(afFlexibleMinX)
    of 'r': result.incl(afFlexibleMaxX)
    else: assert(false, "Wrong autoresizing mask!")
    case s[1]
    of 'h': result.incl(afFlexibleHeight)
    of 't': result.incl(afFlexibleMinY)
    of 'b': result.incl(afFlexibleMaxY)
    else: assert(false, "Wrong autoresizing mask!")

template `resizingMask=`*(v: View, s: static[string]) = # Deprecated
    const m = autoresizingMaskFromStrLit(s)
    v.autoresizingMask = m

proc isDescendantOf*(subView, superview: View): bool =
    var vi = subView
    while not vi.isNil:
        if vi == superview:
            return true
        vi = vi.superview

proc findSubviewWithName*(v: View, name: string): View =
    for c in v.subviews:
        if c.name == name: return c
        result = c.findSubviewWithName(name)
        if not result.isNil: break

proc enclosingViewOfType*(v: View, T: typedesc): T =
    type TT = T
    var r = v.superview
    while not r.isNil and not (r of T):
        r = r.superview
    if not r.isNil: result = TT(r)

# View ordering
proc temporaryRemoveViewFromSuperview(v: View): bool =
    let s = v.superview
    if not s.isNil:
        let i = s.subviews.find(v)
        if i != -1:
            s.subviews.delete(i)
            v.setNeedsDisplay()
            result = true

proc moveToFront*(v: View) =
    if v.temporaryRemoveViewFromSuperview():
        v.superview.subviews.add(v)

proc moveToBack*(v: View) =
    if v.temporaryRemoveViewFromSuperview():
        v.superview.subviews.insert(v, 0)

template `originForEditor=`(v: View, p: Point) = v.setFrameOrigin(p)
template originForEditor(v: View): Point = v.frame.origin
template `sizeForEditor=`(v: View, p: Size) = v.setFrameSize(p)
template sizeForEditor(v: View): Size = v.frame.size

method visitProperties*(v: View, pv: var PropertyVisitor) {.base.} =
    pv.visitProperty("name", v.name)
    pv.visitProperty("origin", v.originForEditor)
    pv.visitProperty("size", v.sizeForEditor)
    pv.visitProperty("layout", v.autoresizingMask)
    pv.visitProperty("color", v.backgroundColor)

method serializeFields*(v: View, s: Serializer) =
    s.serialize("name", v.name)
    s.serialize("frame", v.frame)
    s.serialize("bounds", v.bounds)
    s.serialize("subviews", v.subviews)
    s.serialize("arMask", v.autoresizingMask)
    s.serialize("color", v.backgroundColor)

method deserializeFields*(v: View, s: Deserializer) =
    var fr: Rect
    s.deserialize("frame", fr)
    v.init(fr)
    s.deserialize("bounds", v.bounds)
    s.deserialize("name", v.name)
    var subviews: seq[View]
    s.deserialize("subviews", subviews)
    for sv in subviews:
        doAssert(not sv.isNil)
        v.addSubview(sv)
    s.deserialize("arMask", v.autoresizingMask)
    s.deserialize("color", v.backgroundColor)

registerClass(View)
