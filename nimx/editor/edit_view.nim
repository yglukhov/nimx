import times, json, math

import view, panel_view, context, undo_manager, toolbar, button, menu, resource
import inspector_panel

import gesture_detector_newtouch
import view_event_handling_new
import window_event_handling

import nimx.property_editors.autoresizing_mask_editor # Imported here to be registered in the propedit registry
import nimx.serializers
import nimx.key_commands
import nimx.pasteboard.pasteboard

import ui_document
import grid_drawing

type
    EventCatchingView = ref object of View
        keyUpDelegate*: proc (event: var Event)
        keyDownDelegate*: proc (event: var Event)
        mouseScrrollDelegate*: proc (event: var Event)
        panningView: View # View that we're currently moving/resizing with `panOp`
        editor: Editor
        panOp: PanOperation
        dragStartTime: float
        origPanRect: Rect
        origPanPoint: Point
        gridSize: Size

    Editor* = ref object
        eventCatchingView: EventCatchingView
        toolbar: Toolbar
        inspector: InspectorPanel
        mSelectedView: View # View that we currently draw selection rect around
        document: UIDocument

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

proc `selectedView=`(e: Editor, v: View) =
    e.mSelectedView = v
    e.inspector.setInspectedObject(v)

template selectedView(e: Editor): View = e.mSelectedView

template `selectedView=`(e: EventCatchingView, v: View) = e.editor.selectedView = v
template selectedView(e: EventCatchingView): View = e.editor.selectedView

method acceptsFirstResponder(v: EventCatchingView): bool = true

method onKeyUp(v: EventCatchingView, e : var Event): bool =
    # echo "editor onKeyUp ", e.keyCode
    if not v.keyUpDelegate.isNil:
        v.keyUpDelegate(e)

method onKeyDown(v: EventCatchingView, e : var Event): bool =
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
        if v.gridSize == zeroSize:
            v.gridSize = newSize(24, 24)
        else:
            v.gridSize = zeroSize
        v.setNeedsDisplay()

    if not v.keyDownDelegate.isNil:
        v.keyDownDelegate(e)

proc endEditing*(e: Editor) =
    e.eventCatchingView.removeFromSuperview()
    e.toolbar.removeFromSuperview()

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
                    if not e.eventCatchingView.selectedView.isNil:
                        v.init(newRect(10, 10, 100, 100))
                        e.eventCatchingView.selectedView.addSubview(v)
                    else:
                        v.init(newRect(200, 200, 100, 100))
                        e.document.view.addSubview(v)
                    e.eventCatchingView.selectedView = v
                items.add(menuItem)

        menu.items = items
        menu.popupAtPoint(b, newPoint(0, 27))
    e.toolbar.addSubview(b)

when savingAndLoadingEnabled:
    proc createLoadButton(e: Editor) =
        let b = Button.new(newRect(0, 30, 120, 20))
        b.title = "Open"
        b.onAction do():
            e.selectedView = nil
            e.document.open()
        e.toolbar.addSubview(b)

    proc createSaveButton(e: Editor) =
        let b = Button.new(newRect(0, 30, 120, 20))
        b.title = "Save As..."
        b.onAction do():
            e.document.saveAs()
        e.toolbar.addSubview(b)

proc startEditingInView*(editedView, editingView: View): Editor =
    ## editedView - the view to edit
    ## editingView - parent view for the editor UI
    result.new()
    result.document = newUIDocument()
    result.document.view = editedView

    let editor = result

    editor.eventCatchingView = EventCatchingView.new(editingView.bounds)
    editor.eventCatchingView.editor = editor
    editor.eventCatchingView.autoresizingMask = {afFlexibleWidth, afFlexibleHeight}
    editingView.addSubview(editor.eventCatchingView)

    const toolbarHeight = 30
    editor.toolbar = Toolbar.new(newRect(0, 0, 20, toolbarHeight))
    editingView.addSubview(editor.toolbar)

    editor.createNewViewButton()
    when savingAndLoadingEnabled:
        editor.createLoadButton()
        editor.createSaveButton()

    editor.inspector = InspectorPanel.new(newRect(680, 100, 300, 600))
    editingView.addSubview(editor.inspector)

proc findSubviewAtPointAux(v: View, p: Point): View =
    for i in countdown(v.subviews.len - 1, 0):
        let s = v.subviews[i]
        var pp = s.convertPointFromParent(p)
        if pp.inRect(s.bounds):
            result = s.findSubviewAtPointAux(pp)
            if not result.isNil:
                break
    if result.isNil:
        result = v

proc findSubviewAtPoint(v: View, p: Point): View =
    result = v.findSubviewAtPointAux(p)
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
    if v.gridSize.width > 0: result = nearestOf(val, v.gridSize.width)

proc nearestToGridY(v: EventCatchingView, val: Coord): Coord =
    result = val
    if v.gridSize.height > 0: result = nearestOf(val, v.gridSize.height)

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

        if v.panOp == poDrag and not e.localPosition.inRect(sr):
            # Either there is no view selected, or mousedown missed selected
            # view. Find some view under mouse and start dragging it.

            # Convert to coordinates of edited view
            let lpos = v.editor.document.view.convertPointFromWindow(v.convertPointToWindow(e.localPosition))
            v.panningView = v.editor.document.view.findSubviewAtPoint(lpos)

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

    if v.gridSize != zeroSize:
        drawGrid(v.bounds, v.gridSize)

    if not v.selectedView.isNil:
        v.drawSelectionRect()
