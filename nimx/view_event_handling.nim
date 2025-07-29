import view, event, drag_and_drop, tables, algorithm, sequtils

export event

method onKeyDown*(v: View, e: var Event): bool {.base, gcsafe.} = discard
method onKeyUp*(v: View, e: var Event): bool {.base, gcsafe.} = discard
method onTextInput*(v: View, s: string): bool {.base, gcsafe.} = discard
method onGestEvent*(d: GestureDetector, e: var Event): bool {.base, gcsafe.} = discard
method onScroll*(v: View, e: var Event): bool {.base, gcsafe.} = discard

method name*(v: View): string {.base.} =
  result = "View"

method onTouchEv*(v: View, e: var Event): bool {.base, gcsafe.} =
  for d in v.gestureDetectors:
    let r = d.onGestEvent(e)
    result = result or r

  if e.buttonState == bsDown:
    if v.acceptsFirstResponder and not v.isFirstResponder:
      result = v.makeFirstResponder()

method onInterceptTouchEv*(v: View, e: var Event): bool {.base, gcsafe.} =
  discard

method onListenTouchEv*(v: View, e: var Event): bool {.base, gcsafe.} =
  discard

proc isMainWindow(v: View, e : var Event): bool =
  result = v == e.window

method onMouseIn*(v: View, e: var Event) {.base, gcsafe.} =
  discard

method onMouseOver*(v: View, e: var Event) {.base, gcsafe.} =
  discard

method onMouseOut*(v: View, e: var Event) {.base, gcsafe.} =
  discard

proc handleMouseOverEvent*(v: Window, e: var Event) =
  let localPosition = e.localPosition
  for vi in v.mouseOverListeners:
    e.localPosition = vi.convertPointFromWindow(e.position)
    if e.localPosition.inRect(vi.bounds):
      if not vi.mouseInside:
        vi.onMouseIn(e)
        vi.mouseInside = true
      else:
        vi.onMouseOver(e)
    elif vi.mouseInside:
      vi.mouseInside = false
      vi.onMouseOut(e)
  e.localPosition = localPosition

proc processDragEvent*(b: DragSystem, e: var Event) =
  b.itemPosition = e.position
  if b.pItem.isNil:
    return

  e.window.needsDisplay = true
  let target = e.window.findSubviewAtPoint(e.position)
  var dropDelegate: DragDestinationDelegate
  if not target.isNil:
    dropDelegate = target.dragDestination

  if e.buttonState == bsUp:
    if not dropDelegate.isNil:
      dropDelegate.onDrop(target, b.pItem)
    stopDrag()
    return

  if b.prevTarget != target:
    if not b.prevTarget.isNil and not b.prevTarget.dragDestination.isNil:
      b.prevTarget.dragDestination.onDragExit(b.prevTarget, b.pItem)
    if not target.isNil and not dropDelegate.isNil:
      dropDelegate.onDragEnter(target, b.pItem)

  elif not target.isNil and not target.dragDestination.isNil:
      dropDelegate.onDrag(target, b.pItem)

  b.prevTarget = target

proc getCurrentTouches(e: Event): TableRef[int, View] {.inline.}=
  assert(not e.window.isNil, "Internal error")
  result = e.window.mCurrentTouches

proc setTouchTarget(e: Event, v: View, override = false)=
  let ct = e.getCurrentTouches()
  if (override or e.pointerId notin ct) and not v.window.isNil:
    ct[e.pointerId] = v

proc getTouchTarget(e: Event): View =
  let ct = e.getCurrentTouches()
  if e.pointerId in ct:
    var r = ct[e.pointerId]
    if not r.window.isNil:
      result = r
    else:
      ct.del(e.pointerId)

proc removeTouchTarget(e: Event)=
  let ct = e.getCurrentTouches()
  ct.del(e.pointerId)

iterator superviews(v: View): View =
  var sv = v.superview
  while not sv.isNil:
    yield sv
    sv = sv.superview

proc processTouchEvent*(v: View, e: var Event): bool {.gcsafe.}

proc handeBsDown(v: View, e: var Event): bool =
  if v.hidden: return false
  v.interceptEvents = false
  v.touchTarget = nil
  if v.subviews.len == 0:
    result = v.onTouchEv(e)
    if result:
      e.setTouchTarget(v)
    return

  if v.onInterceptTouchEv(e):
    v.interceptEvents = true
    result = v.onTouchEv(e)
    if result:
      e.setTouchTarget(v)
    return

  let localPosition = e.localPosition
  for i in countdown(v.subviews.high, 0):
    let s = v.subviews[i]
    e.localPosition = s.convertPointFromParent(localPosition)
    if e.localPosition.inRect(s.bounds):
      result = s.processTouchEvent(e)
      if result:
        v.touchTarget = s
        e.setTouchTarget(s)
        break

  e.localPosition = localPosition
  if result and v.onListenTouchEv(e):
    discard v.onTouchEv(e)
  if not result:
    result = v.onTouchEv(e)
    if result:
      e.setTouchTarget(v)

proc handleBsUpUnknown(v: View, e: var Event): bool =
  var target = e.getTouchTarget()
  if v.subviews.len == 0 or target.isNil:
    result = v.onTouchEv(e)
  else:
    var superviews = toSeq(target.superviews)
    for i in countdown(high(superviews), 0):
      let sv = superviews[i]
      if sv.onInterceptTouchEv(e):
        sv.interceptEvents = true
        result = sv.onTouchEv(e)
        if result:
          v.touchTarget = sv
          e.setTouchTarget(sv, true)
          return

    var localPosition = e.localPosition
    e.localPosition = target.convertPointFromWindow(localPosition)
    for sv in target.superviews:
      if sv.onListenTouchEv(e):
        discard sv.onTouchEv(e)
    result = target.onTouchEv(e)
    e.localPosition = localPosition

proc processTouchEvent*(v: View, e: var Event): bool {.gcsafe.} =
  if e.buttonState == bsDown:
    result = v.handeBsDown(e)
  elif numberOfActiveTouches() > 0:
    result = v.handleBsUpUnknown(e)
  if e.buttonState == bsUp:
    if v.isMainWindow(e) and numberOfActiveTouches() == 1:
      v.touchTarget = nil
      v.interceptEvents = false
    removeTouchTarget(e)

proc processMouseWheelEvent*(v: View, e : var Event): bool =
  if v.hidden: return false
  let localPosition = e.localPosition
  for i in countdown(v.subviews.high, 0):
    let s = v.subviews[i]
    e.localPosition = s.convertPointFromParent(localPosition)
    if e.localPosition.inRect(s.bounds):
      result = s.processMouseWheelEvent(e)
      if result:
        break
  if not result:
    e.localPosition = localPosition
    result = v.onScroll(e)

proc processKeyboardEvent*(v: View, e: var Event): bool =
  if v.hidden: return false

  case e.kind
  of etKeyboard:
    if e.buttonState == bsDown:
      result = v.onKeyDown(e)
    else:
      result = v.onKeyUp(e)
  of etTextInput:
    result = v.onTextInput(e.text)
  else:
    discard
