import times, json, math

import nimx / [view, panel_view, context, undo_manager, toolbar, button, menu, inspector_panel,
      gesture_detector, window_event_handling, view_event_handling, abstract_window,
      serializers, key_commands, ui_resource, private/async]

import nimx/property_editors/[autoresizing_mask_editor, standard_editors] # Imported here to be registered in the propedit registry
import nimx/pasteboard/pasteboard
import ui_document, grid_drawing, editor_types, editor_workspace

proc `selectedView=`(e: Editor, v: View) =
  e.mSelectedView = v
  e.inspector.setInspectedObject(v)

template selectedView(e: Editor): View = e.mSelectedView

template `selectedView=`(e: EventCatchingView, v: View) = e.editor.selectedView = v
template selectedView(e: EventCatchingView): View = e.editor.selectedView

method acceptsFirstResponder(v: EventCatchingView): bool = true

method onKeyUp(v: EventCatchingView, e : var Event): bool {.gcsafe.} =
  # echo "editor onKeyUp ", e.keyCode
  if not v.keyUpDelegate.isNil:
    v.keyUpDelegate(e)

proc gridSize(v: EventCatchingView): float = v.mGridSize
proc `gridSize=`(v: EventCatchingView, val: float) =
  v.mGridSize = val
  v.editor.workspace.gridSize = if v.gridSize >= 10.0: newSize(v.gridSize, v.gridSize) else: zeroSize
  v.setNeedsDisplay()

proc toggleGrid(v: EventCatchingView)=
  if v.gridSize == 0.0:
    v.gridSize = 24.0
  else:
    v.gridSize = 0.0

method onKeyDown(v: EventCatchingView, e : var Event): bool {.gcsafe.} =
  let u = v.editor.document.undoManager
  let cmd = commandFromEvent(e)
  case cmd
  of kcUndo:
    if u.canUndo(): u.undo()
  of kcRedo:
    if u.canRedo(): u.redo()
  of kcCopy, kcCut:
    let sv = v.selectedView
    if not sv.isNil:
      let s = newJsonSerializer()
      s.serialize(sv)
      let pbi = newPasteboardItem(ViewPboardKind, $s.jsonNode)
      pasteboardWithName(PboardGeneral).write(pbi)
      if cmd == kcCut:
        let svSuperview = sv.superview
        u.pushAndDo("Cut view") do():
          sv.removeFromSuperview()
          v.selectedView = nil
        do():
          svSuperview.addSubview(sv)
          v.selectedView = sv
  of kcPaste:
    let pbi = pasteboardWithName(PboardGeneral).read(ViewPboardKind)
    if not pbi.isNil:
      let jn = parseJson(pbi.data)
      echo jn
      let s = newJsonDeserializer(parseJson(pbi.data))
      var nv: View
      s.deserialize(nv)
      doAssert(not nv.isNil)
      var targetView = v.selectedView
      if targetView.isNil:
        targetView = v.editor.document.view
      u.pushAndDo("Paste view") do():
        targetView.addSubview(nv)
      do():
        nv.removeFromSuperview()
  of kcOpen:
    v.editor.document.open()
  of kcSave:
    v.editor.document.save()
  of kcSaveAs:
    v.editor.document.saveAs()
  else: discard

  if e.keyCode == VirtualKey.Delete:
    let sv = v.selectedView
    if not sv.isNil:
      let svSuper = sv.superview
      u.pushAndDo("Delete view") do():
        sv.removeFromSuperView()
        v.selectedView = nil
      do():
        svSuper.addSubview(sv)
        v.selectedView = sv
  elif e.keyCode == VirtualKey.G:
    v.toggleGrid()

  if not v.keyDownDelegate.isNil:
    v.keyDownDelegate(e)

proc endEditing*(e: Editor) =
  e.eventCatchingView.removeFromSuperview()

proc setupNewViewButton(e:Editor, b: Button) =
  # let b = Button.new(newRect(0, 30, 120, 20))
  # b.title = "New view"
  b.onAction do():
    var menu : Menu
    menu.new()
    var items = newSeq[MenuItem]()
    for c in registeredClassesOfType(View):
      closureScope:
        let menuItem = newMenuItem(c)
        menuItem.action = proc() =
          let v = View(newObjectOfClass(menuItem.title))
          if not e.eventCatchingView.selectedView.isNil:
            v.init(newRect(10, 10, 100, 100))
            e.eventCatchingView.selectedView.addSubview(v)
          else:
            v.init(newRect(200, 200, 100, 100))
            e.document.view.addSubview(v)
          e.eventCatchingView.selectedView = v
          v.name = e.document.defaultName(menuItem.title)

        items.add(menuItem)

    menu.items = items
    menu.popupAtPoint(b, newPoint(0, 27))

when savingAndLoadingEnabled:
  proc setupLoadButton(e: Editor, b: Button) =
    b.onAction do():
      e.selectedView = nil
      e.document.open()

  proc setupSaveButton(e: Editor, b: Button) =
    b.onAction do():
      e.document.saveAs()

proc setupSimulateButton(e: Editor, b: Button)=
  b.onAction do():
    var simulateWnd = newWindow(newRect(100, 100, e.document.view.bounds.width, e.document.view.bounds.height))
    simulateWnd.title = "Simulate"
    simulateWnd.addSubview(
      deserializeView(
        e.document.serializeView()
        )
      )

    echo "simulate"

proc startNimxEditorAsync*(wnd: Window) {.async.}=
  var editor = new(Editor)

  editor.workspace = new(EditorWorkspace, wnd.bounds)
  editor.workspace.autoresizingMask = {afFlexibleWidth, afFlexibleHeight}
  wnd.addSubview(editor.workspace)

  editor.eventCatchingView = EventCatchingView.new(wnd.bounds)
  editor.eventCatchingView.editor = editor
  editor.eventCatchingView.autoresizingMask = {afFlexibleWidth, afFlexibleHeight}
  wnd.addSubview(editor.eventCatchingView)

  editor.document = newUIDocument(editor)
  editor.workspace.addSubview(editor.document.view)

  var ui = await loadUiResourceAsync("assets/top_panel.nimx")
  var topPanel = ui.view
  topPanel.setFrameOrigin(zeroPoint)
  wnd.addSubview(topPanel)

  editor.setupNewViewButton(ui.getView(Button, "new_view_btn"))
  when savingAndLoadingEnabled:
    editor.setupLoadButton(ui.getView(Button, "open_btn"))
    editor.setupSaveButton(ui.getView(Button, "save_btn"))
  editor.setupSimulateButton(ui.getView(Button, "simulate"))

  var gridButton = ui.getView(Button, "grid_button")
  gridButton.onAction do():
    editor.eventCatchingView.toggleGrid()

  ui.getView(View, "gridSize").initPropertyEditor(editor.eventCatchingView, "gridSize", editor.eventCatchingView.gridSize)

  editor.inspector = InspectorPanel.new(newRect(0, 0, 300, 600))
  editor.inspector.onPropertyChanged do(name: string):
    wnd.setNeedsDisplay()

  var propWnd = newWindow(newRect(680, 100, 300, 600))
  propWnd.title = "Inspector"

  editor.inspector.autoresizingMask = {afFlexibleWidth, afFlexibleHeight}
  propWnd.addSubview(editor.inspector)

  wnd.onClose = proc()=
    quit(0)

proc startNimxEditor*(wnd: Window) =
  asyncCheck startNimxEditorAsync(wnd)

proc subviewAtPointAux(v: View, p: Point): View =
  for i in countdown(v.subviews.len - 1, 0):
    let s = v.subviews[i]
    var pp = s.convertPointFromParent(p)
    if pp.inRect(s.bounds):
      result = s.subviewAtPointAux(pp)
      if not result.isNil:
        break
  if result.isNil:
    result = v

proc subviewAtPoint(v: View, p: Point): View =
  result = v.subviewAtPointAux(p)
  if result == v: result = nil

proc knobRect(b: Rect, po: PanOperation): Rect =
  const cornerKnobRadius = 4
  const edgeKnobRadius = 2

  case po
  of poDragTL: newRect(b.x - cornerKnobRadius, b.y - cornerKnobRadius, cornerKnobRadius * 2, cornerKnobRadius * 2)
  of poDragTR: newRect(b.maxX - cornerKnobRadius, b.y - cornerKnobRadius, cornerKnobRadius * 2, cornerKnobRadius * 2)
  of poDragBL: newRect(b.x - cornerKnobRadius, b.maxY - cornerKnobRadius, cornerKnobRadius * 2, cornerKnobRadius * 2)
  of poDragBR: newRect(b.maxX - cornerKnobRadius, b.maxY - cornerKnobRadius, cornerKnobRadius * 2, cornerKnobRadius * 2)

  of poDragB: newRect(b.x + b.width / 2 - edgeKnobRadius, b.maxY - edgeKnobRadius, edgeKnobRadius * 2, edgeKnobRadius * 2)
  of poDragL: newRect(b.x - edgeKnobRadius, b.y + b.height / 2 - edgeKnobRadius, edgeKnobRadius * 2, edgeKnobRadius * 2)
  of poDragR: newRect(b.maxX - edgeKnobRadius, b.y + b.height / 2 - edgeKnobRadius, edgeKnobRadius * 2, edgeKnobRadius * 2)
  of poDragT: newRect(b.x + b.width / 2 - edgeKnobRadius, b.y - edgeKnobRadius, edgeKnobRadius * 2, edgeKnobRadius * 2)

  else: zeroRect

proc panOperation(r: Rect, p: Point): PanOperation =
  result = poDrag
  for po in poDragTL .. poDragR:
    if p.inRect(knobRect(r, po).inset(-2, -2)): return po

proc localRectOfEditedView(v: EventCatchingView, editedView: View): Rect =
  v.convertRectFromWindow(editedView.convertRectToWindow(editedView.bounds))

proc selectionRect(v: EventCatchingView): Rect =
  let s = v.selectedView
  if not s.isNil:
    result = v.localRectOfEditedView(s)

proc nearestOf(v: Coord, t: Coord): Coord =
  round(v / t) * t

proc nearestToGridX(v: EventCatchingView, val: Coord): Coord =
  result = val
  if v.gridSize > 0: result = nearestOf(val, v.gridSize)

proc nearestToGridY(v: EventCatchingView, val: Coord): Coord =
  result = val
  if v.gridSize > 0: result = nearestOf(val, v.gridSize)

method onTouchEv*(v: EventCatchingView, e: var Event): bool =
  result = procCall v.View.onTouchEv(e)

  case e.buttonState
  of bsDown:
    v.dragStartTime = epochTime()

    v.origPanPoint = e.localPosition
    v.panningView = v.selectedView
    v.panOp = poDrag
    let sr = v.selectionRect
    if not v.panningView.isNil:
      v.panOp = panOperation(sr, e.localPosition)

    let lpos = v.editor.document.view.convertPointFromWindow(v.convertPointToWindow(e.localPosition))
    var clickAtView = v.editor.document.view.subviewAtPoint(lpos)
    if v.panOp == poDrag and (not e.localPosition.inRect(sr) or clickAtView != v.panningView):
      # Either there is no view selected, or mousedown missed selected
      # view. Find some view under mouse and start dragging it.

      # Convert to coordinates of edited view
      v.panningView = clickAtView

    if not v.panningView.isNil:
      v.origPanRect = v.panningView.frame
      v.setNeedsDisplay()
  of bsUp:
    if epochTime() - v.dragStartTime < 0.3:
      v.selectedView = v.panningView
      v.setNeedsDisplay()
    else:
      let pv = v.panningView
      if not pv.isNil:
        let origFrame = v.origPanRect
        let newFrame = pv.frame
        v.editor.document.undoManager.pushAndDo("Move/resize view") do():
          pv.setFrame(newFrame)
        do():
          pv.setFrame(origFrame)
  else:
    if not v.panningView.isNil:
      let delta = e.localPosition - v.origPanPoint
      var newFrame = v.origPanRect
      if v.panOp in { poDragTL, poDragBL, poDragL }:
        let mx = newFrame.maxX
        newFrame.origin.x = v.nearestToGridX(newFrame.x + delta.x)
        newFrame.size.width = mx - newFrame.origin.x
      elif v.panOp in { poDragTR, poDragBR, poDragR }:
        let mx = v.nearestToGridX(newFrame.maxX + delta.x)
        newFrame.size.width = mx - newFrame.origin.x

      if v.panOp in { poDragTL, poDragTR, poDragT }:
        let my = newFrame.maxY
        newFrame.origin.y = v.nearestToGridY(newFrame.y + delta.y)
        newFrame.size.height = my - newFrame.origin.y
      elif v.panOp in { poDragBL, poDragBR, poDragB }:
        let my = v.nearestToGridY(newFrame.maxY + delta.y)
        newFrame.size.height = my - newFrame.origin.y

      if v.panOp == poDrag:
        newFrame.origin += delta
        newFrame.origin.x = v.nearestToGridX(newFrame.origin.x)
        newFrame.origin.y = v.nearestToGridY(newFrame.origin.y)

      v.panningView.setFrame(newFrame)

  result = true

proc drawSelectionRect(v: EventCatchingView) =
  let c = currentContext()
  c.fillColor = clearColor()
  c.strokeColor = newGrayColor(0.3)
  c.strokeWidth = 1

  let sr = v.selectionRect
  c.drawRect(sr)

  c.fillColor = newGrayColor(0.7)
  var knobRect: Rect

  for po in poDragTL .. poDragR:
    c.drawEllipseInRect(knobRect(sr, po))

method draw*(v: EventCatchingView, r: Rect) =
  procCall v.View.draw(r)

  if not v.selectedView.isNil:
    v.drawSelectionRect()

