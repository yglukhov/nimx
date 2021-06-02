import strutils
import sample_registry
import nimx / [ view, font, context, button, gesture_detector, view_event_handling ]

var bttnMesage = "Press or drag buttons"
var draggedbttnHandleEvent = false

type EventsPriorityView = ref object of View
    welcomeFont: Font

type CustomControl* = ref object of Control
type MyScrollListener = ref object of OnScrollListener
    updatedView: View
    curr_pos_y: float

type MyDragListener = ref object of OnScrollListener
    updatedView: View
    curr_pos: Point

type ContentView = ref object of View
type ScissorView = ref object of View
type DraggedButton = ref object of Button


########################
method init(v: ContentView, w: Window, r: Rect) =
    procCall v.View.init(w, r)

proc newContentView*(w: Window, frame: Rect): ContentView =
    result.new()
    result.init(w, frame)

method init(v: ScissorView, w: Window, r: Rect) =
    procCall v.View.init(w, r)

proc newScissorView*(w: Window, frame: Rect): ScissorView =
    result.new()
    result.init(w, frame)

method clipType*(v: ScissorView): ClipType = ctDefaultClip

method init(b: DraggedButton, w: Window, r: Rect) =
    procCall b.Button.init(w, r)

proc newDraggedButton*(w: Window, r: Rect): DraggedButton =
    result.new()
    result.init(w, r)

########################

method onScrollProgress*(lis: MyScrollListener, dx, dy : float32, e : var Event) =
    if draggedbttnHandleEvent:
        return

    let v = lis.updatedView
    let speed = 1.0
    v.setFrameOrigin( newPoint(0, dy * speed + lis.curr_pos_y) )
    v.setNeedsDisplay()

var old_pos = newPoint(-1, -1)
method onInterceptTouchEv*(v: ContentView, e: var Event): bool =
    if (abs(old_pos.y - e.position.y) > 2) and (old_pos.x >= 0) and (not draggedbttnHandleEvent):
        if not v.touchTarget.isNil:
            var state = e.buttonState
            e.buttonState = bsUp
            discard v.touchTarget.onTouchEv(e)
            e.buttonState = state

        return true
    return false

method onTapDown*(lis: MyScrollListener, e : var Event) =
    old_pos = e.position
    lis.curr_pos_y = lis.updatedView.frame.origin.y

method onTapUp*(lis: MyScrollListener, dx, dy : float32, e : var Event) =
    old_pos = newPoint(-1, -1)

method onListenTouchEv*(v: ContentView, e: var Event): bool =
    return true

######################## Drag button

method onScrollProgress*(lis: MyDragListener, dx, dy : float32, e : var Event) =
    let v = lis.updatedView
    let speed = 1.0
    v.setFrameOrigin( newPoint(dx * speed, dy * speed) + lis.curr_pos )
    v.setNeedsDisplay()

method onTapDown*(lis: MyDragListener, e : var Event) =
    lis.curr_pos = lis.updatedView.frame.origin
    draggedbttnHandleEvent = true

method onTapUp*(lis: MyDragListener, dx, dy : float32, e : var Event) =
    draggedbttnHandleEvent = false

########################

method init(v: EventsPriorityView, w: Window, r: Rect) =
    procCall v.View.init(w, r)

    var scissorView = newScissorView(w, newRect(0, 25 , 360, 250))
    var contentView = newContentView(w, newRect(0, 25 , 360, 250))
    var sl : MyScrollListener
    new(sl)
    sl.updatedView = contentView
    contentView.addGestureDetector(newScrollGestureDetector(sl))

    v.addSubview(scissorView)
    scissorView.addSubview(contentView)

    for i in 0 .. 10:
        closureScope:
            let button = newButton(w, newRect(5.Coord, (i * 20).Coord, 150.Coord, 20.Coord))
            button.title = "Button " & intToStr(i)
            button.onAction do():
                echo "Click ", button.title
                bttnMesage = "Click " & button.title
            contentView.addSubview(button)

    let button = newButton(w, newRect(170.Coord, 20, 50.Coord, 50.Coord))
    button.title = "dragged"
    button.onAction do():
        echo "Click ", button.title
        bttnMesage = "Click " & button.title
    contentView.addSubview(button)

    var dl : MyDragListener
    new(dl)
    dl.updatedView = button
    button.addGestureDetector(newScrollGestureDetector(dl))


method draw(v: EventsPriorityView, r: Rect) =
    template gfxCtx: untyped = v.window.gfxCtx
    template fontCtx: untyped = gfxCtx.fontCtx
    if v.welcomeFont.isNil:
        v.welcomeFont = systemFontOfSize(fontCtx, 20)
    gfxCtx.fillColor = blackColor()
    gfxCtx.drawText(v.welcomeFont, newPoint(10, 5), bttnMesage)

registerSample(EventsPriorityView, "EventsPriority")
