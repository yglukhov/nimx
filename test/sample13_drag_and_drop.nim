import sample_registry
import strutils
import variant

import nimx.view
import nimx.font
import nimx.context
import nimx.composition
import nimx.button
import nimx.autotest

import nimx.gesture_detector
import nimx.view_event_handling_new
import nimx.event
import nimx.drag_and_drop
import nimx.text_field
import nimx.expanding_view
import nimx.view_render_to_image

type DragAndDropView = ref object of View

type MyDropDelegate* = ref object of BaseDragAndDrop

type MyDragDelegate* = ref object of BaseDragAndDrop

type DraggedView* = ref object of View

method onTouchEv*(v: DraggedView, e: var Event): bool =
    if e.buttonState == bsDown:
        let dItem = DraggedItem.new()
        dItem.data = newVariant(v)
        dItem.image = v.screenShotRecursive()
        startDrag(dItem)

proc newDraggedView*(r: Rect): DraggedView =
    result.new()
    result.init(r)


#============= MyDropDelegate ==============

method onDragEnter*(dd: MyDropDelegate, i: DraggedItem) =
    let sourceView = i.data.get(DraggedView)

    let label = i.target.subviews[1].TextField
    if not sourceView.name.isNil:
        label.text = "drag over: " & sourceView.name
        i.target.backgroundColor.a = 0.5

method onDragExit*(dd: MyDropDelegate, i: DraggedItem) =
    let sourceView = i.data.get(DraggedView)

    i.target.backgroundColor.a = 1.0
    let label = i.target.subviews[1].TextField
    label.text = "drag over: "

method onDrop*(dd: MyDropDelegate, i: DraggedItem) =
    let sourceView = i.data.get(DraggedView)
    i.target.backgroundColor = sourceView.backgroundColor
    i.target.backgroundColor.a = 1.0
    let label = i.target.subviews[1].TextField
    label.text = "drag over: "


proc createDraggedView(pos: Point, name: string): View =
    result = newDraggedView(newRect(pos.x, pos.y, 150, 60))
    result.name = name
    result.backgroundColor = newColor(0.0, 1.0, 0.0, 1.0)

    let label_name = newLabel(newRect(2, 0, 200, 40))
    label_name.text = result.name
    result.addSubView(label_name)

    let label_drop = newLabel(newRect(2, 20, 200, 35))
    label_drop.text = "drop to: "
    result.addSubView(label_drop)

proc createDropView(pos: Point, name: string, delegate: MyDropDelegate): View =
    result = newView(newRect(pos.x, pos.y, 200, 200))
    result.name = name
    result.backgroundColor = newColor(1.0, 0.0, 0.0, 1.0)
    result.dragAndDropDelegate = delegate
    result.dragAndDropDelegate.MyDropDelegate.view = result

    let label_name = newLabel(newRect(2, 150, 200, 40))
    label_name.text = result.name
    result.addSubView(label_name)

    let label_drop = newLabel(newRect(2, 170, 200, 35))
    label_drop.text = "drop : "
    result.addSubView(label_drop)


method init(v: DragAndDropView, r: Rect) =
    procCall v.View.init(r)

    let dropDelegate = MyDropDelegate.new()
    let red_view = createDropView(newPoint(50.0, 80.0), "red_drop_view", dropDelegate)

    let blue_view = createDropView(newPoint(350.0, 80.0), "blue_drop_view", dropDelegate)
    blue_view.backgroundColor = newColor(0.0, 0.0, 1.0, 1.0)

    v.addSubView(red_view)
    v.addSubView(blue_view)

    let draggedView1 = createDraggedView(newPoint(50, 10), "dragged_1")
    v.addSubView(draggedView1)

    let draggedView2 = createDraggedView(newPoint(350, 10), "dragged_2")
    draggedView2.backgroundColor = newColor(1.0, 1.0, 0.0, 1.0)
    v.addSubView(draggedView2)

    let expView = newExpandingView(newRect(50, 300, 200, 400), true)
    expView.title = "Expanded View "
    expView.dragAndDropDelegate = new(MyDragDelegate)
    expView.dragAndDropDelegate.activateStep = 4.0
    v.addSubview(expView)

    let exp_drop_view = createDropView(newPoint(350.0, 80.0), "exp_drop_view", dropDelegate)
    exp_drop_view.backgroundColor = newColor(1.0, 0.0, 1.0, 1.0)
    expView.addContent(exp_drop_view)

method draw(v: DragAndDropView, r: Rect) =
    let c = currentContext()
    c.fillColor = whiteColor()

registerSample(DragAndDropView, "DragAndDrop")
