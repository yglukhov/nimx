import ./[view, scroll_bar, event, layout_vars]
import kiwi
import math
export view

type ScrollView* = ref object of View
  mContentView: View
  mHorizontalScrollBar, mVerticalScrollBar: ScrollBar
  mOnScrollCallback: proc() {.gcsafe.}
  constraints: seq[Constraint]
  xPos, yPos: Variable # Scroll positions

const scrollBarWidth = 12.Coord

method init*(v: ScrollView) =
  procCall v.View.init()
  v.xPos = newVariable()
  v.yPos = newVariable()
  v.addSubview(ScrollBar.new())
  v.addSubview(ScrollBar.new())

proc onScrollBar(v: ScrollView, sb: ScrollBar) {.gcsafe.}

proc onScroll*(v: ScrollView, cb: proc() {.gcsafe.}) =
  v.mOnScrollCallback = cb

proc `horizontalScrollBar=`*(v: ScrollView, s: ScrollBar) =
  v.addSubview(s)

proc `verticalScrollBar=`*(v: ScrollView, s: ScrollBar) =
  v.addSubview(s)

template horizontalScrollBar*(v: ScrollView): ScrollBar = v.mHorizontalScrollBar
template verticalScrollBar*(v: ScrollView): ScrollBar = v.mVerticalScrollBar

proc contentView*(v: ScrollView): View =
  v.mContentView

proc contentSize(v: ScrollView): Size =
  let cv = v.contentView
  if not cv.isNil:
    result = cv.frame.size

proc scrollPosition*(v: ScrollView): Point =
  ## Result: Point where x and y between 0.0 .. 1.0
  let cs = v.contentSize
  let b = v.bounds
  let csx = cs.width - b.width
  let csy = cs.height - b.height
  result.x = if csx > 0.0: b.x / csx else: 0
  result.y = if csy > 0.0: b.y / csy else: 0

proc recalcScrollbarKnobPositions(v: ScrollView) =
  echo "RECALC!"
  let sp = v.scrollPosition()
  if not v.mHorizontalScrollBar.isNil:
    v.mHorizontalScrollBar.value = sp.x
  if not v.mVerticalScrollBar.isNil:
    v.mVerticalScrollBar.value = sp.y

method updateLayout*(v: ScrollView) =
  procCall v.View.updateLayout()
  let cs = v.contentSize
  let cvBounds = v.bounds.size
  # echo "Update"
  if not v.mVerticalScrollBar.isNil:
    v.mVerticalScrollBar.knobSize = cvBounds.height / cs.height
    v.mVerticalScrollBar.value = (v.layout.vars.y.value - v.yPos.value) / (cs.height - cvBounds.height)
    v.mVerticalScrollBar.hidden = v.mVerticalScrollBar.knobSize == 1.0
    # echo "KS: ", v.mVerticalScrollBar.knobSize
    # echo "CS: ", cs.height
  if not v.mHorizontalScrollBar.isNil:
    v.mHorizontalScrollBar.knobSize = cvBounds.width / cs.width
    v.mHorizontalScrollBar.value = (v.layout.vars.x.value - v.xPos.value) / (cs.width - cvBounds.width)
    v.mHorizontalScrollBar.hidden = v.mHorizontalScrollBar.knobSize == 1.0

method onScroll*(v: ScrollView, e: var Event): bool =
  let s = v.window.layoutSolver
  s.suggestValue(v.xPos, v.xPos.value + e.offset.x * 10)
  s.suggestValue(v.yPos, v.yPos.value + e.offset.y * 10)

  v.setNeedsDisplay()
  v.setNeedsLayout()

  if not v.mOnScrollCallback.isNil:
    v.mOnScrollCallback()

  result = true

proc onScrollBar(v: ScrollView, sb: ScrollBar) =
  let cs = v.contentSize
  let cvBounds = v.bounds.size
  let s = v.window.layoutSolver
  if sb.isHorizontal:
    let p = (cs.width - cvBounds.width) * sb.value
    s.suggestValue(v.xPos, v.layout.vars.x.value - p)
  else:
    let p = (cs.height - cvBounds.height) * sb.value
    s.suggestValue(v.yPos, v.layout.vars.y.value - p)

  v.setNeedsDisplay()
  v.setNeedsLayout()

  if not v.mOnScrollCallback.isNil:
    v.mOnScrollCallback()

proc rebuildConstraints(v: ScrollView) =
  for c in v.constraints:
    v.removeConstraint(c)

  v.constraints.setLen(0)

  let cv = v.mContentView
  if not cv.isNil:
    v.constraints.add(cv.layout.vars.left == v.layout.vars.left + v.xPos)
    v.constraints.add(cv.layout.vars.top == v.layout.vars.top + v.yPos)
    v.constraints.add(cv.layout.vars.top <= v.layout.vars.top)
    v.constraints.add(cv.layout.vars.left <= v.layout.vars.left)
    var c = cv.layout.vars.bottom >= v.layout.vars.bottom
    c.strength = MEDIUM
    v.constraints.add(c)
    c = cv.layout.vars.right >= v.layout.vars.right
    c.strength = MEDIUM
    v.constraints.add(c)

  let hs = v.mHorizontalScrollBar
  if not hs.isNil:
    v.constraints.add(hs.layout.vars.left == v.layout.vars.left)
    v.constraints.add(hs.layout.vars.right == v.layout.vars.right - scrollBarWidth)
    v.constraints.add(hs.layout.vars.bottom == v.layout.vars.bottom)
    v.constraints.add(hs.layout.vars.height == scrollBarWidth)

  let vs = v.mVerticalScrollBar
  if not vs.isNil:
    v.constraints.add(vs.layout.vars.right == v.layout.vars.right)
    v.constraints.add(vs.layout.vars.top == v.layout.vars.top)
    v.constraints.add(vs.layout.vars.bottom == v.layout.vars.bottom - scrollBarWidth)
    v.constraints.add(vs.layout.vars.width == scrollBarWidth)

  for c in v.constraints:
    v.addConstraint(c)

method didAddSubview*(v: ScrollView, s: View) =
  procCall v.View.didAddSubview(s)
  if s of ScrollBar:
    let sb = ScrollBar(s)
    if sb.isHorizontal:
      if not v.mHorizontalScrollBar.isNil:
        v.mHorizontalScrollBar.removeFromSuperview()
      v.mHorizontalScrollBar = sb
    else:
      if not v.mVerticalScrollBar.isNil:
        v.mVerticalScrollBar.removeFromSuperview()
      v.mVerticalScrollBar = sb
    sb.onAction do(): v.onScrollBar(sb)

  else:
    if not v.mContentView.isNil:
      v.mContentView.removeFromSuperview()
    v.mContentView = s

  # Make sure content view is the first one
  if not v.mContentView.isNil and v.subviews[0] != v.mContentView:
    let idx = v.subviews.find(v.mContentView)
    swap(v.subviews[0], v.subviews[idx])

  v.rebuildConstraints()

method didRemoveSubview*(v: ScrollView, s: View) =
  procCall v.View.didRemoveSubview(s)
  if s == v.mContentView: v.mContentView = nil
  elif s == v.mVerticalScrollBar: v.mVerticalScrollBar = nil
  elif s == v.mHorizontalScrollBar: v.mHorizontalScrollBar = nil
  v.rebuildConstraints()

method viewWillMoveToWindow*(v: ScrollView, w: Window) =
  procCall v.View.viewWillMoveToWindow(w)
  let wnd = v.window
  if not wnd.isNil:
    let s = wnd.layoutSolver
    s.removeEditVariable(v.xPos)
    s.removeEditVariable(v.yPos)

method viewDidMoveToWindow*(v: ScrollView) =
  procCall v.View.viewDidMoveToWindow()
  let wnd = v.window
  if not wnd.isNil:
    let s = wnd.layoutSolver
    s.addEditVariable(v.xPos, WEAK)
    s.addEditVariable(v.yPos, WEAK)

proc scrollToRect*(v: ScrollView, r: Rect) =
  ## If necessary scrolls to reveal the rect `r` which is in content bounds
  ## coordinates.
  let cv = v.mContentView
  if not cv.isNil:
    let cvBounds = cv.frame
    var o = cvBounds.origin
    if o.x + r.x < 0:
      o.x = -r.x
    elif r.maxX + o.x > v.bounds.maxX:
      o.x = v.bounds.width - r.maxX
    if o.y + r.y < 0:
      o.y = -r.y
    elif r.maxY + o.y > v.bounds.maxY:
      o.y = v.bounds.height - r.maxY

    let w = v.window
    let s = if not w.isNil: w.layoutSolver else: nil
    if s.isNil:
      v.xPos.value = o.x
      v.yPos.value = o.y
    else:
      s.suggestValue(v.xPos, o.x)
      s.suggestValue(v.yPos, o.y)
      v.setNeedsLayout()
    v.recalcScrollbarKnobPositions()
  echo "SCROLL"

proc scrollToBottom*(v: ScrollView)=
  let rect = newRect(0, v.contentSize.height - v.bounds.height, v.bounds.width, v.bounds.height)
  v.scrollToRect(rect)

proc scrollToTop*(v: ScrollView)=
  v.scrollToRect(newRect(0, 0, v.bounds.width, v.bounds.height))

proc scrollPageUp*(v: ScrollView)=
  let cvBounds = v.bounds
  var o = cvBounds.origin
  if o.y > 0:
    o.y = max(0, o.y - cvBounds.height)
  let rect = newRect(o.x, o.y, cvBounds.width, cvBounds.height)
  v.scrollToRect(rect)

proc scrollPageDown*(v: ScrollView)=
  let cvBounds = v.bounds
  var o = cvBounds.origin
  if o.y < cvBounds.maxY:
    o.y = min(v.contentSize.height - cvBounds.height, o.y + cvBounds.height)
  let rect = newRect(o.x, o.y, cvBounds.width, cvBounds.height)
  v.scrollToRect(rect)

method clipType*(v: ScrollView): ClipType = ctDefaultClip

registerClass(ScrollView)
