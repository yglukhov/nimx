import times

import view, panel_view, context, undo_manager, toolbar, button, menu
import inspector_panel

import gesture_detector_newtouch
import view_event_handling_new
import window_event_handling

type
    EventCatchingView = ref object of View
        keyUpDelegate*: proc (event: var Event)
        keyDownDelegate*: proc (event: var Event)
        mouseScrrollDelegate*: proc (event: var Event)
        selectedView: View # View that we currently draw selection rect around
        panningView: View # View that we're currently moving/resizing with `panOp`
        editor: Editor
        panOp: PanOperation
        dragStartTime: float
        origPanRect: Rect
        origPanPoint: Point

    Editor* = ref object
        editedView: View
        eventCatchingView: EventCatchingView
        undoManager: UndoManager
        toolbar: Toolbar
        inspector: InspectorPanel

    PanOperation = enum
        poDrag
        poDragTL
        poDragT
        poDragTR
        poDragB
        poDragBR
        poDragBL
        poDragL
        poDragR

method acceptsFirstResponder(v: EventCatchingView): bool = true

method onKeyUp(v: EventCatchingView, e : var Event): bool =
    echo "editor onKeyUp ", e.keyCode
    if not v.keyUpDelegate.isNil:
        v.keyUpDelegate(e)

method onKeyDown(v: EventCatchingView, e : var Event): bool =
    let u = v.editor.undoManager
    when defined(macosx):
        if e.keyCode == VirtualKey.Z and (alsoPressed(VirtualKey.LeftGUI) or alsoPressed(VirtualKey.RightGUI)):
            if (alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift)) and u.canRedo():
                u.redo()
            elif u.canUndo():
                u.undo()
    else:
        if e.keyCode == VirtualKey.Z and
                (alsoPressed(VirtualKey.LeftControl) or alsoPressed(VirtualKey.RightControl)) and u.canUndo():
            u.undo()
        elif e.keyCode == VirtualKey.Y and
                (alsoPressed(VirtualKey.LeftControl) or alsoPressed(VirtualKey.RightControl)) and u.canRedo():
            u.redo()

    if not v.keyDownDelegate.isNil:
        v.keyDownDelegate(e)

proc endEditing*(e: Editor) =
    e.eventCatchingView.removeFromSuperview()
    e.toolbar.removeFromSuperview()

template closureScope*(body: untyped): stmt = (proc() = body)()

proc createNewViewButton(e: Editor) =
    let b = Button.new(newRect(0, 30, 120, 20))
    b.title = "New view"
    b.onAction do():
        var menu : Menu
        menu.new()
        var items = newSeq[MenuItem]()
        for c in registeredClassesOfType(View):
            closureScope:
                let menuItem = newMenuItem(c)
                menuItem.action = proc() =
                    let v = View(newObjectOfClass(menuItem.title))
                    v.init(newRect(500, 500, 100, 100))
                    e.editedView.addSubview(v)
                    e.eventCatchingView.selectedView = v
                items.add(menuItem)

        menu.items = items
        menu.popupAtPoint(b, newPoint(0, 27))
    e.toolbar.addSubview(b)

proc startEditingInView*(editedView, editingView: View): Editor =
    ## editedView - the view to edit
    ## editingView - parent view for the editor UI
    result.new()
    result.editedView = editedView
    result.undoManager = newUndoManager()

    let editor = result

    editor.eventCatchingView = EventCatchingView.new(editingView.bounds)
    editor.eventCatchingView.editor = editor
    editingView.addSubview(editor.eventCatchingView)

    const toolbarHeight = 30
    editor.toolbar = Toolbar.new(newRect(0, 0, 20, toolbarHeight))
    editingView.addSubview(editor.toolbar)

    editor.createNewViewButton()

    editor.inspector = InspectorPanel.new(newRect(680, 200, 200, 800))
    editingView.addSubview(editor.inspector)

proc findSubviewAtPoint(v: View, p: Point): View =
    for i in countdown(v.subviews.len - 1, 0):
        let s = v.subviews[i]
        var pp = s.convertPointFromParent(p)
        if pp.inRect(s.bounds):
            result = s.findSubviewAtPoint(pp)
            if not result.isNil:
                break
    if result.isNil:
        result = v

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

method onTouchEv*(v: EventCatchingView, e: var Event): bool =
    result = procCall v.View.onTouchEv(e)

    case e.buttonState
    of bsDown:
        v.dragStartTime = epochTime()

        v.origPanPoint = e.localPosition

        # Convert to coordinates of edited view
        let lpos = v.editor.editedView.convertPointFromWindow(v.convertPointToWindow(e.localPosition))
        v.panningView = v.editor.editedView.findSubviewAtPoint(lpos)

        v.origPanRect = v.panningView.frame

        v.panOp = poDrag
        if v.panningView == v.selectedView:
            v.panOp = panOperation(v.selectionRect, e.localPosition)

        v.setNeedsDisplay()
    of bsUp:
        if epochTime() - v.dragStartTime < 0.3:
            v.selectedView = v.panningView
            v.editor.inspector.setInspectedObject(v.selectedView)
            v.setNeedsDisplay()
        else:
            let pv = v.panningView
            let origFrame = v.origPanRect
            let newFrame = pv.frame
            v.editor.undoManager.pushAndDo("Move/resize view") do():
                pv.setFrame(newFrame)
            do():
                pv.setFrame(origFrame)

    else:
        let delta = e.localPosition - v.origPanPoint
        var newFrame = v.origPanRect
        if v.panOp in { poDragTL, poDragBL, poDragL }:
            newFrame.origin.x = newFrame.x + delta.x
            newFrame.size.width -= delta.x
        elif v.panOp in { poDragTR, poDragBR, poDragR }:
            newFrame.size.width += delta.x

        if v.panOp in { poDragTL, poDragTR, poDragT }:
            newFrame.origin.y = newFrame.y + delta.y
            newFrame.size.height -= delta.y
        elif v.panOp in { poDragBL, poDragBR, poDragB }:
            newFrame.size.height += delta.y

        if v.panOp == poDrag:
            newFrame.origin += delta

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
