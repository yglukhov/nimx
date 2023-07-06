import strutils
import sample_registry
import nimx / [ view, font, context, button, gesture_detector, view_event_handling ]

var bttnMesage {.threadvar.}: string
bttnMesage = "Press or drag buttons"
var draggedbttnHandleEvent = false

type
    EventsPriorityView = ref object of View
        welcomeFont: Font

    CustomControl* = ref object of Control
    MyScrollListener = ref object of OnScrollListener
        updatedView: ContentView
        curr_pos_y: float

    MyDragListener = ref object of OnScrollListener
        updatedView: DraggedButton
        start: Point

    ContentView = ref object of View
        oldPos: Point

    ScissorView = ref object of View
    DraggedButton = ref object of View
        clickPos: Point

########################
method init(v: ContentView, r: Rect) =
    procCall v.View.init(r)

proc newContentView*(frame: Rect): ContentView =
    result.new()
    result.init(frame)

method init(v: ScissorView, r: Rect) =
    procCall v.View.init(r)

proc newScissorView*(frame: Rect): ScissorView =
    result.new()
    result.init(frame)

method clipType*(v: ScissorView): ClipType = ctDefaultClip

########################

method onScrollProgress*(lis: MyScrollListener, dx, dy : float32, e : var Event) =
    if draggedbttnHandleEvent:
        return

    let v = lis.updatedView
    let speed = 1.0
    v.setFrameOrigin( newPoint(0, dy * speed + lis.curr_pos_y) )
    v.setNeedsDisplay()

method onInterceptTouchEv*(v: ContentView, e: var Event): bool =
    if draggedbttnHandleEvent:
        return false

    if e.buttonState == bsUnknown and abs(v.oldPos.y - e.position.y) > 5:
        if v.touchTarget of Button:
            v.touchTarget.Button.setState(bsUp)
        return true

    return false

method onListenTouchEv*(v: ContentView, e: var Event): bool =
    return true


method onTapDown*(lis: MyScrollListener, e : var Event) =
    lis.updatedView.oldPos = e.position
    lis.curr_pos_y = lis.updatedView.frame.origin.y

method onTapUp*(lis: MyScrollListener, dx, dy : float32, e : var Event) =
    lis.updatedView.oldPos = newPoint(-1, -1)

######################## Drag button

method onScrollProgress*(lis: MyDragListener, dx, dy : float32, e : var Event) =
    let v = lis.updatedView
    v.setFrameOrigin(newPoint(dx, dy) + lis.start)
    v.setNeedsDisplay()

method onTapDown*(lis: MyDragListener, e : var Event) =
    lis.start = lis.updatedView.frame.origin
    lis.updatedView.clickPos = e.position
    draggedbttnHandleEvent = true

method onTapUp*(lis: MyDragListener, dx, dy : float32, e : var Event) =
    draggedbttnHandleEvent = false

method onInterceptTouchEv*(v: DraggedButton, e: var Event): bool =
    if e.buttonState == bsUnknown and e.position.distanceTo(v.clickPos) > 5:
        if v.touchTarget of Button:
            v.touchTarget.Button.setState(bsUp)
        return true

    return false


method onListenTouchEv*(v: DraggedButton, e: var Event): bool =
    return true


########################

method init(v: EventsPriorityView, r: Rect) =
    procCall v.View.init(r)

    var scissorView = newScissorView(newRect(0, 25 , 360, 250))
    var contentView = newContentView(newRect(0, 25 , 360, 250))
    var sl = MyScrollListener.new()
    sl.updatedView = contentView
    contentView.addGestureDetector(newScrollGestureDetector(sl))
    contentView.name = "contentView"

    v.addSubview(scissorView)
    scissorView.addSubview(contentView)

    for i in 0 .. 10:
        closureScope:
            let button = newButton(newRect(5, (i.Coord * 20), 150, 20))
            button.title = "Button " & $i
            button.name = button.title
            button.onAction do():
                echo "Click ", button.title
                bttnMesage = "Click " & button.title
            contentView.addSubview(button)

    let button = newButton(newRect(0, 0, 50, 50))
    button.title = "dragged"
    button.onAction do():
        echo "Click ", button.title
        bttnMesage = "Click " & button.title

    var draggedButton = DraggedButton.new(newRect(170, 10, 50, 50))
    draggedButton.addSubview(button)
    contentView.addSubview(draggedButton)

    var dl = MyDragListener(updatedView: draggedButton)
    draggedButton.addGestureDetector(newScrollGestureDetector(dl))


method draw*(v: EventsPriorityView, r: Rect) =
    let c = currentContext()
    if v.welcomeFont.isNil:
        v.welcomeFont = systemFontOfSize(20)
    c.fillColor = blackColor()
    c.drawText(v.welcomeFont, newPoint(10, 5), bttnMesage)

registerSample(EventsPriorityView, "EventsPriority")
