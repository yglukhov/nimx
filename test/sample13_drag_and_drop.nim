import variant
import sample_registry
import nimx / [ view, view_event_handling, drag_and_drop, text_field, expanding_view,
                view_render_to_image ]
import nimx/pasteboard/pasteboard_item

type DragAndDropView = ref object of View
type MyDropDelegate* = ref object of DragDestinationDelegate
type DraggedView* = ref object of View

const PboardSampleDrag* = "nimx.sample.drag"

method onTouchEv*(v: DraggedView, e: var Event): bool =
    if e.buttonState == bsDown:
        let dpi = newPasteboardItem(PboardSampleDrag, v.name)
        let image = v.screenShot()
        startDrag(dpi, image)

#============= MyDropDelegate ==============

method onDragEnter*(dd: MyDropDelegate, target: View, i: PasteboardItem) =
    target.backgroundColor.a = 0.5
    let label = target.subviews[1].TextField
    label.text = "drag over: " & i.data

method onDragExit*(dd: MyDropDelegate, target: View, i: PasteboardItem) =
    target.backgroundColor.a = 1.0
    let label = target.subviews[1].TextField
    label.text = "drag over: "

method onDrop*(dd: MyDropDelegate, target: View, i: PasteboardItem) =
    let label = target.subviews[1].TextField
    label.text = "drag over: "

    if i.data == "yellow":
        target.backgroundColor = newColor(1.0, 1.0, 0.0, 1.0)
    if i.data == "green":
        target.backgroundColor = newColor(0.0, 1.0, 0.0, 1.0)

#============= Views ==============

proc createDraggedView(pos: Point, name: string): View =
    result = DraggedView.new(newRect(pos.x, pos.y, 150, 60))
    result.name = name
    result.backgroundColor = newColor(0.0, 1.0, 0.0, 1.0)

    let label_name = newLabel(newRect(2, 0, 200, 40))
    label_name.text = result.name
    result.addSubView(label_name)

proc createDropView(pos: Point, name: string, delegate: MyDropDelegate): View =
    result = newView(newRect(pos.x, pos.y, 200, 200))
    result.name = name
    result.backgroundColor = newColor(1.0, 0.0, 0.0, 1.0)
    result.dragDestination = delegate

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

    let draggedView1 = createDraggedView(newPoint(50, 10), "green")
    v.addSubView(draggedView1)

    let draggedView2 = createDraggedView(newPoint(350, 10), "yellow")
    draggedView2.backgroundColor = newColor(1.0, 1.0, 0.0, 1.0)
    v.addSubView(draggedView2)

    let expView = newExpandingView(newRect(50, 300, 200, 400), true)
    expView.title = "Expanded View "
    v.addSubview(expView)

    let exp_drop_view = createDropView(newPoint(350.0, 80.0), "exp_drop_view", dropDelegate)
    exp_drop_view.backgroundColor = newColor(1.0, 0.0, 1.0, 1.0)
    expView.addContent(exp_drop_view)

registerSample(DragAndDropView, "DragAndDrop")
