
import sample_registry

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

type DragAndDropView = ref object of View
    welcomeFont: Font

type MyDragProxyDelegate* = ref object of BaseDragAndDrop
    proxy: View

type MyDropDelegate* = ref object of BaseDragAndDrop
    proxy: View

method onDragStart*(dd: MyDragProxyDelegate, e: DragEvent) =
    dd.proxy = newView(newRect(10, 10, 80, 40))
    dd.proxy.name = "dragged_proxy"
    dd.proxy.backgroundColor = newColor(0.0, 1.0, 0.0, 0.5)
    dd.proxy.setFrameOrigin(dd.mCurrentPos + newPoint(1, 1))
    e.draggedView.window.addSubView(dd.proxy)

method onDrag*(dd: MyDragProxyDelegate, e: DragEvent) =
    # echo "onDrag target ", e.targetView.name
    dd.proxy.setFrameOrigin(dd.proxy.frame.origin + e.deltaPos)

method onDrop*(dd: MyDragProxyDelegate, e: DragEvent) =
    dd.proxy.removeFromSuperview()
    let label = e.draggedView.subviews[1].TextField
    if not e.targetView.name.isNil:
        label.text = "drop to: " & e.targetView.name
    else:
        label.text = "drop to: "

method onDragOverEnter*(dd: MyDropDelegate, e: DragEvent) =
    let label = e.targetView.subviews[1].TextField
    if not e.draggedView.name.isNil:
        label.text = "drop: " & e.draggedView.name

method onDragOverExit*(dd: MyDropDelegate, e: DragEvent) =
    let label = e.targetView.subviews[1].TextField
    label.text = "drop: "

# method onDragOver*(dd: MyDropDelegate, e: DragEvent) =
#     let label = e.targetView.subviews[1].TextField
#     if not e.draggedView.name.isNil:
#         label.text = "drop: " & e.draggedView.name

method onDropOver*(dd: MyDropDelegate, e: DragEvent) =
    let label = e.targetView.subviews[1].TextField
    label.text = "drop: "

proc createDraggedView(pos: Point, name: string): View =
    result = newView(newRect(pos.x, pos.y, 150, 60))
    result.name = name
    result.backgroundColor = newColor(0.0, 1.0, 0.0, 1.0)
    result.dragAndDropDelegate = MyDragProxyDelegate.new()
    result.dragAndDropDelegate.activateStep = 4.0

    let label_name = newLabel(newRect(2, 0, 150, 40))
    label_name.text = result.name
    result.addSubView(label_name)

    let label_drop = newLabel(newRect(2, 20, 150, 35))
    label_drop.text = "drop to: "
    result.addSubView(label_drop)

proc createDropView(pos: Point, name: string, delegate: MyDropDelegate): View =
    result = newView(newRect(pos.x, pos.y, 200, 200))
    result.name = name
    result.backgroundColor = newColor(1.0, 0.0, 0.0, 1.0)
    result.dragAndDropDelegate = delegate

    let label_name = newLabel(newRect(2, 200, 150, 40))
    label_name.text = result.name
    result.addSubView(label_name)

    let label_drop = newLabel(newRect(2, 220, 150, 35))
    label_drop.text = "drop : "
    result.addSubView(label_drop)


method init(v: DragAndDropView, r: Rect) =
    procCall v.View.init(r)

    let dropDelegate = MyDropDelegate.new()
    let red_view = createDropView(newPoint(50.0, 80.0), "red_view", dropDelegate)

    let blue_view = createDropView(newPoint(350.0, 80.0), "blue_view", dropDelegate)
    blue_view.backgroundColor = newColor(0.0, 0.0, 1.0, 1.0)

    v.addSubView(red_view)
    v.addSubView(blue_view)

    let draggedView1 = createDraggedView(newPoint(50, 10), "dragged_1")
    v.addSubView(draggedView1)

    let draggedView2 = createDraggedView(newPoint(350, 10), "dragged_2")
    draggedView2.backgroundColor = newColor(1.0, 1.0, 0.0, 1.0)
    v.addSubView(draggedView2)

method draw(v: DragAndDropView, r: Rect) =
    let c = currentContext()
    c.fillColor = whiteColor()

registerSample(DragAndDropView, "DragAndDrop")
