import typetraits, tables
import types, context, animation_runner, layout_vars
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

  ConstraintWithPrototype = object
    proto: Constraint
    inst: Constraint

  LayoutInfo = object
    vars*: LayoutVars
    constraints: seq[ConstraintWithPrototype]

  View* = ref object of RootRef
    window*: Window
    name*: string
    frame: Rect         ## view rect in superview coordinate system
    bounds: Rect        ## view rect in its own coordinate system, starting from 0,0
    subviews*: seq[View]
    superview*: View
    backgroundColor*: Color
    gestureDetectors*: seq[GestureDetector]
    touchTarget*: View
    interceptEvents*: bool    ## when view starts to handle tap, this flag set to true
    mouseInside*: bool
    handleMouseOver: bool
    hidden*: bool
    dragDestination*: DragDestinationDelegate
    layout*: LayoutInfo

  Window* = ref object of View
    firstResponder*: View     ## handler of untargeted (keyboard and menu) input
    animationRunners*: seq[AnimationRunner]
    needsDisplay*: bool
    needsLayout*: bool
    mouseOverListeners*: seq[View]
    pixelRatio*: float32
    viewportPixelRatio*: float32
    mActiveBgColor*: Color
    layoutSolver*: Solver
    onClose*: proc()
    mCurrentTouches*: TableRef[int, View]
    mAnimationEnabled*: bool

proc init(i: var LayoutInfo) =
  i.vars.init()

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

proc instantiateConstraint(v: View, c: var ConstraintWithPrototype) =
  # Instantiate constrinat prototype and add it to the window
  let ic = newConstraint(c.proto.expression, c.proto.op, c.proto.strength)
  let indexOfViewInSuper = v.superview.subviews.find(v)
  assert(indexOfViewInSuper != -1)
  let count = ic.expression.terms.len
  for i in 0 ..< count:
    replacePlaceholderVar(v, indexOfViewInSuper, ic.expression.terms[i].variable)

  assert(c.inst.isNil, "Internal error")
  c.inst = ic

  assert(not v.window.isNil, "Internal error")
  v.window.layoutSolver.addConstraint(ic)

proc findConstraint(v: View, c: Constraint): int {.inline.} =
  for i, cc in v.layout.constraints:
    if cc.proto == c:
      return i
  return -1

proc addConstraint*(v: View, c: Constraint) =
  v.layout.constraints.add(ConstraintWithPrototype(proto: c))
  if not v.window.isNil:
    v.instantiateConstraint(v.layout.constraints[^1])

proc addConstraints*(v: View, cc: openarray[Constraint]) =
  for c in cc: v.addConstraint(c)

proc removeConstraint*(v: View, c: Constraint) =
  let idx = v.findConstraint(c)
  assert(idx != -1)
  let inst = v.layout.constraints[idx].inst
  v.layout.constraints.del(idx)
  if not v.window.isNil:
    assert(not inst.isNil)
    v.window.layoutSolver.removeConstraint(inst)

proc removeConstraints*(v: View, cc: openarray[Constraint]) =
  for c in cc: v.removeConstraint(c)

proc constraints*(v: View): seq[Constraint] =
  result = newSeqOfCap[Constraint](v.layout.constraints.len)
  for c in v.layout.constraints: result.add(c.proto)

method init*(v: View) {.base, gcsafe.} =
  v.layout.init()

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

proc new*[V: View](v: typedesc[V]): V =
  result.new()
  result.init()

method convertPointToParent*(v: View, p: Point): Point {.base, gcsafe.} = p + v.frame.origin - v.bounds.origin
method convertPointFromParent*(v: View, p: Point): Point {.base, gcsafe.} = p - v.frame.origin + v.bounds.origin

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
method acceptsFirstResponder*(v: View): bool {.base, gcsafe.} = false
method viewShouldResignFirstResponder*(v, newFirstResponder: View): bool {.base, gcsafe.} = true
method viewDidBecomeFirstResponder*(v: View) {.base, gcsafe.} = discard

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

method makeFirstResponder*(v: View): bool {.base, gcsafe.} =
  let w = v.window
  if not w.isNil:
    result = w.makeFirstResponder(v)

template isFirstResponder*(v: View): bool =
  not v.window.isNil and v.window.firstResponder == v

####
method viewWillMoveToSuperview*(v: View, s: View) {.base, gcsafe.} = discard
method viewWillMoveToWindow*(v: View, w: Window) {.base, gcsafe.} =
  if not v.window.isNil:
    v.window.removeMouseOverListener(v)
    if v.window.firstResponder == v and w != v.window:
      discard v.window.makeFirstResponder(nil)

    for c in v.layout.constraints.mitems:
      v.window.layoutSolver.removeConstraint(c.inst)
      c.inst = nil

  if not w.isNil:
    if v.handleMouseOver:
      w.addMouseOverListener(v)

  for s in v.subviews:
    s.window = v.window
    s.viewWillMoveToWindow(w)

method viewDidMoveToWindow*(v: View){.base, gcsafe.} =
  if not v.window.isNil:
    for c in v.layout.constraints.mitems:
      v.instantiateConstraint(c)

  for s in v.subviews:
    s.viewDidMoveToWindow()

proc moveToWindow(v: View, w: Window) =
  v.window = w
  for s in v.subviews:
    s.moveToWindow(w)

method markNeedsDisplay*(w: Window) {.base, gcsafe.} =
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

method didAddSubview*(v, s: View) {.base, gcsafe.} = discard
method didRemoveSubview*(v, s: View) {.base, gcsafe.} = discard

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

method removeFromSuperview*(v: View) {.base, gcsafe.} =
  v.removeFromSuperview(true)

proc removeAllSubviews*(v: View) =
  while v.subviews.len > 0:
    let s = v.subviews[0]
    s.removeFromSuperview()

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

method replaceSubview*(v: View, subviewIndex: int, withView: View) {.base, gcsafe.} =
  v.subviews[subviewIndex].removeFromSuperview()
  v.insertSubview(withView, subviewIndex)

proc replaceSubview*(v, s, withView: View) =
  assert(s.superview == v)
  let i = v.subviews.find(s)
  v.replaceSubview(i, withView)

proc findSubview*(v: View, n: string): View=
  for s in v.subviews:
    if s.name == n:
      return s
    return s.findSubview(n)

proc getSubview*[T](v: View, n: string): T =
  result = v.findSubviewWithName(n).T

method clipType*(v: View): ClipType {.base, gcsafe.} = ctNone

proc recursiveDrawSubviews*(view: View) {.gcsafe.}

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
#    echo "bounds: ", v.bounds
#    echo "frame: ", v.frame
    assert(false, "Not implemented")

  c.withTransform tmpTransform:
    if v.clipType() == ctDefaultClip:
      c.withClippingRect v.bounds:
        v.recursiveDrawSubviews()
    else:
      v.recursiveDrawSubviews()

method draw*(view: View, rect: Rect) {.base, gcsafe.} =
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

method updateLayout*(v: View) {.base, gcsafe.} = discard

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

method frame*(v: View): Rect {.base, gcsafe.} = v.frame
method bounds*(v: View): Rect {.base, gcsafe.} = v.bounds

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

template `originForEditor=`(v: View, p: Point) = discard # Deprecated???
template originForEditor(v: View): Point = zeroPoint
template `sizeForEditor=`(v: View, p: Size) = discard # Deprecated???
template sizeForEditor(v: View): Size = zeroSize

method visitProperties*(v: View, pv: var PropertyVisitor) {.base, gcsafe.} =
  pv.visitProperty("name", v.name)
  pv.visitProperty("origin", v.originForEditor)
  pv.visitProperty("size", v.sizeForEditor)
  pv.visitProperty("color", v.backgroundColor)

method serializeFields*(v: View, s: Serializer) =
  s.serialize("name", v.name)
  s.serialize("frame", v.frame)
  s.serialize("bounds", v.bounds)
  s.serialize("subviews", v.subviews)
  s.serialize("color", v.backgroundColor)

proc isLastInSuperview(d: View): bool =
  d.superview.subviews[^1] == d

proc constraintsForFixedFrame*(f: Rect, superSize: Size, m: set[AutoresizingFlag]): seq[Constraint] =
  # Don't use!
  if afFlexibleMinX in m:
    result.add(selfPHS.width == f.width)
    result.add(selfPHS.right == superPHS.right - (superSize.width - f.maxX))
  elif afFlexibleWidth in m:
    result.add(selfPHS.left == superPHS.left + f.x)
    result.add(selfPHS.right == superPHS.right - (superSize.width - f.maxX))
  else:
    result.add(selfPHS.left == superPHS.left + f.x)
    result.add(selfPHS.width == f.width)

  if afFlexibleMinY in m:
    result.add(selfPHS.height == f.height)
    result.add(selfPHS.bottom == superPHS.bottom - (superSize.height - f.maxY))
  elif afFlexibleHeight in m:
    result.add(selfPHS.top == superPHS.top + f.y)
    result.add(selfPHS.bottom == superPHS.bottom - (superSize.height - f.maxY))
  else:
    result.add(selfPHS.top == superPHS.top + f.y)
    result.add(selfPHS.height == f.height)

proc dump(d, root: View, indent, output: var string, printer: proc(v: View): string) =
  let oldIndentLen = indent.len
  if d != root:
    var p = d.superview
    if p != root:
      indent &= (if p.isLastInSuperview(): "   " else: "│  ")

    output &= indent
    output &= (if d.isLastInSuperview(): "└─ " else: "├─ ")

  output &= printer(d)
  output &= '\n'

  for c in d.subviews:
    dump(c, root, indent, output, printer)

  indent.setLen(oldIndentLen)

proc dump*(v: View, printer: proc(v: View): string): string =
  var indent = newStringOfCap(256)
  result = newStringOfCap(2048)
  v.dump(v, indent, result, printer)

proc dump*(v: View): string =
  v.dump() do(v: View) -> string:
    v.className

registerClass(View)
