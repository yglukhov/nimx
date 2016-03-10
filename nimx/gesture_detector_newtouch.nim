import view
import event
import view_event_handling_new
import system_logger
import app

type
    BaseGestureDetector* = ref object of GestureDetector

    OnScrollListener* = ref object of RootObj
    BaseScrollListener* = ref object of OnScrollListener
        tapDownDelegate*:           proc(e : var Event)
        scrollProgressDelegate*:    proc(dx, dy : float32, e : var Event)
        tapUpDelegate*:             proc(dx, dy : float32, e : var Event)
    ScrollDetector* = ref object of BaseGestureDetector
        listener* : OnScrollListener
        tap_down : Point
        last_active_point : Point
        pointers : seq[Event]
        dx_offset, dy_offset : float32
        last_fired_dx, last_fired_dy : float32
        firing : bool

    OnTapListener* = proc(tapPoint : Point)
    TapGestureDetector* = ref object of BaseGestureDetector
        tapListener* : OnTapListener
        down_timestamp: uint32
        down_position: Point
        fired : bool

    OnZoomListener* = ref object of RootObj
    ZoomGestureDetector* = ref object of BaseGestureDetector
        last_distance : float32
        last_zoom : float32
        pointers : seq[Event]
        listener : OnZoomListener
        firing : bool

    OnRotateListener* = ref object of RootObj
    RotateGestureDetector* = ref object of BaseGestureDetector
        last_start :  Point
        last_end : Point
        pointers : seq[Event]
        listener : OnRotateListener
        firing : bool
        angle : float32
        angle_offset : float32

    OnFlingListener* = ref object of RootObj
    BaseFlingListener* = ref object of OnFlingListener
        flingDelegate*: proc(vx, vy: float)
    FlingGestureDetector* = ref object of BaseGestureDetector
        flingListener* : OnFlingListener
        prev_ev, this_ev: Event

method onTapDown*(ls: OnScrollListener, e : var Event) {.base.} = discard
method onScrollProgress*(ls: OnScrollListener, dx, dy : float32, e : var Event) {.base.} = discard
method onTapUp*(ls: OnScrollListener, dx, dy : float32, e : var Event) {.base.} = discard

method onZoomStart*(ls: OnZoomListener) {.base.} = discard
method onZoomProgress*(ls: OnZoomListener, scale : float32) {.base.} = discard
method onZoomFinish*(ls: OnZoomListener) {.base.} = discard

method onRotateStart*(ls : OnRotateListener) {.base.} = discard
method onRotateProgress*(ls : OnRotateListener, angle : float32) {.base.} = discard
method onRotateFinish*(ls : OnRotateListener) {.base.} = discard

method onFling*(ls : OnFlingListener, vx, vy: float) {.base.} = discard

proc newTapGestureDetector*(listener : OnTapListener) : TapGestureDetector =
    new(result)
    result.tapListener = listener

proc newScrollGestureDetector*(listener : OnScrollListener) : ScrollDetector =
    new(result)
    result.pointers = @[]
    result.listener = listener
    result.dx_offset = 0.0'f32
    result.dy_offset = 0.0'f32
    result.last_fired_dx = 0.0'f32
    result.last_fired_dy = 0.0'f32
    result.firing = false

method onTapDown*(ls: BaseScrollListener, e : var Event) =
    if not ls.tapDownDelegate.isNil:
        ls.tapDownDelegate(e)

method onScrollProgress*(ls: BaseScrollListener, dx, dy : float32, e : var Event) =
    if not ls.scrollProgressDelegate.isNil:
        ls.scrollProgressDelegate(dx,dy,e)

method onTapUp*(ls: BaseScrollListener, dx, dy : float32, e : var Event) =
    if not ls.tapUpDelegate.isNil:
        ls.tapUpDelegate(dx,dy,e)

proc newBaseScrollListener*(
        tapD : proc(e : var Event),
        scrollD: proc(dx, dy : float32, e : var Event),
        tapUpD: proc(dx, dy : float32, e : var Event)
        ): BaseScrollListener =
    result.new
    result.tapDownDelegate = tapD
    result.scrollProgressDelegate = scrollD
    result.tapUpDelegate = tapUpD

proc newFlingGestureDetector*(listener : OnFlingListener) : FlingGestureDetector =
    new(result)
    result.flingListener = listener

method onFling*(ls : BaseFlingListener, vx, vy: float) =
    if not ls.flingDelegate.isNil:
        ls.flingDelegate(vx,vy)

proc newBaseFlingListener*(delegate: proc(vx, vy: float)): BaseFlingListener =
    result.new
    result.flingDelegate = delegate

proc newZoomGestureDetector*(listener : OnZoomListener) : ZoomGestureDetector =
    new(result)
    result.pointers = @[]
    result.listener = listener
    result.last_zoom = 1.0'f32
    result.firing = false

proc newRotateGestureDetector*(listener : OnRotateListener) : RotateGestureDetector =
    new(result)
    result.pointers = @[]
    result.listener = listener
    result.firing = false
    result.angle = 0.0'f32
    result.angle_offset = 0.0'f32

proc getPointersCenter(arr : openarray[Event]) : Point =
    result = newPoint(0,0)
    if  arr.len > 0:
        var r = newRect(arr[0].position)
        for i in 1..< arr.len:
            r.union(arr[i].position)
        result = r.centerPoint()

proc checkScroll(d : ScrollDetector, e : var Event) =
    if d.pointers.len > 0:
        if not d.firing:
            d.firing = true
            if not d.listener.isNil:
                d.listener.onTapDown(e)
        else:
            d.dx_offset = d.last_active_point.x - d.tap_down.x + d.dx_offset
            d.dy_offset = d.last_active_point.y - d.tap_down.y + d.dy_offset
        d.tap_down = getPointersCenter(d.pointers)
    else:
        if d.firing:
            d.dx_offset = 0.0'f32
            d.dy_offset = 0.0'f32
            d.firing = false
            if not d.listener.isNil:
                d.listener.onTapUp(d.last_fired_dx, d.last_fired_dy, e)
            d.last_fired_dx = 0.0'f32
            d.last_fired_dy = 0.0'f32
            d.pointers = @[]

method onGestEvent*(d: ScrollDetector, e: var Event) : bool =
    result = true
    if e.buttonState == bsDown:
        d.pointers.add(e)
        d.checkScroll(e)
    if e.buttonState == bsUp:
        for p in 0..< d.pointers.len:
            if d.pointers[p].pointerId == e.pointerId:
                d.pointers.delete(p)
                break
        if d.pointers.len < 1:
            result = false
        d.checkScroll(e)
    if e.buttonState == bsUnknown:
        for p in 0..< d.pointers.len:
            if d.pointers[p].pointerId == e.pointerId:
                d.pointers.delete(p)
                d.pointers.insert(e, p)
                break

    if d.pointers.len > 0:
        d.last_active_point = getPointersCenter(d.pointers)
        if not d.listener.isNil:
            let cen = getPointersCenter(d.pointers)
            d.last_fired_dx = d.last_active_point.x - d.tap_down.x + d.dx_offset
            d.last_fired_dy = d.last_active_point.y - d.tap_down.y + d.dy_offset
            d.listener.onScrollProgress(d.last_fired_dx, d.last_fired_dy, e)


method onGestEvent*(d: TapGestureDetector, e: var Event) : bool =
    result = true
    if e.pointerId != 0: result = false
    else:
        if e.isButtonDownEvent():
            d.down_position = e.position
            d.down_timestamp = e.timestamp
            d.fired = false
        else:
            let timedelta = cast[int](e.timestamp - d.down_timestamp)
            if timedelta > 200:
                result = false
            else:
                if e.isButtonUpEvent():
                    result = false
                    if not d.tapListener.isNil:
                        let dist = d.down_position.distanceTo(e.position)
                        if dist < 20 and (not d.fired):
                            d.tapListener(e.position)
                            d.fired = true

proc checkZoom(d: ZoomGestureDetector) =
    if d.pointers.len > 1:
        d.last_distance = d.pointers[0].position.distanceTo(d.pointers[1].position) / d.last_zoom
        if not d.firing:
            d.firing = true
            if not d.listener.isNil:
                d.listener.onZoomStart()
    else:
        d.last_zoom = 1.0'f32
        if d.firing:
            d.firing = false
            if not d.listener.isNil:
                d.listener.onZoomFinish()



method onGestEvent*(d: ZoomGestureDetector, e: var Event) : bool =
    result = true
    if e.buttonState == bsDown:
        d.pointers.add(e)
        d.checkZoom()
    if e.buttonState == bsUp:
        for p in 0..< d.pointers.len:
            if d.pointers[p].pointerId == e.pointerId:
                d.pointers.delete(p)
                break
        if d.pointers.len < 1:
            result = false
        d.checkZoom()
    if e.buttonState == bsUnknown:
        for p in 0..< d.pointers.len:
            if d.pointers[p].pointerId == e.pointerId:
                d.pointers.delete(p)
                d.pointers.insert(e, p)
                break
    if d.pointers.len > 1:
        let dist = d.pointers[0].position.distanceTo(d.pointers[1].position)
        d.last_zoom = dist / d.last_distance
        if not d.listener.isNil:
            d.listener.onZoomProgress(d.lastZoom)

proc checkRotate(d : RotateGestureDetector) =
    if d.pointers.len > 1:
        d.last_start = d.pointers[0].position
        d.last_end = d.pointers[1].position
        d.angle_offset = d.angle
        if not d.firing:
            d.firing = true
            if not d.listener.isNil:
                d.listener.onRotateStart()
    else:
        d.angle = 0.0'f32
        d.angle_offset = 0.0'f32
        if d.firing:
            d.firing = false
            if not d.listener.isNil:
                d.listener.onRotateFinish()


method onGestEvent*(d: RotateGestureDetector, e: var Event) : bool =
    result = true
    if e.buttonState == bsDown:
        d.pointers.add(e)
        d.checkRotate()
    if e.buttonState == bsUp:
        for p in 0..< d.pointers.len:
            if d.pointers[p].pointerId == e.pointerId:
                d.pointers.delete(p)
                break
        if d.pointers.len < 1:
            result = false
        d.checkRotate()
    if e.buttonState == bsUnknown:
        for p in 0..< d.pointers.len:
            if d.pointers[p].pointerId == e.pointerId:
                d.pointers.delete(p)
                d.pointers.insert(e, p)
                break
    if d.pointers.len > 1:
        let s = newPoint(d.pointers[0].position.x, -(d.pointers[0].position.y))
        let f = newPoint(d.pointers[1].position.x, -(d.pointers[1].position.y))
        let so = newPoint(d.last_start.x, -(d.last_start.y))
        let fo = newPoint(d.last_end.x, -(d.last_end.y))
        d.angle = s.vectorAngle(f) - so.vectorAngle(fo) + d.angle_offset
        if d.angle > 360:
            d.angle = d.angle - 360
        if not d.listener.isNil:
            d.listener.onRotateProgress(d.angle)

proc checkFling*(d: FlingGestureDetector) =
    let dist = d.prev_ev.position.distanceTo(d.this_ev.position)
    let timedelta = d.this_ev.timestamp - d.prev_ev.timestamp
    if not d.flingListener.isNil:
        let vx = 1000'f32 * (d.this_ev.position.x - d.prev_ev.position.x) / float32(timedelta)
        let vy = 1000'f32 * (d.this_ev.position.y - d.prev_ev.position.y) / float32(timedelta)
        if abs(vx)>200 or abs(vy)>200:
            d.flingListener.onFling(vx,vy)

method onGestEvent*(d: FlingGestureDetector, e: var Event) : bool =
    result = true
    if e.pointerId != 0:
       return
    if e.buttonState == bsDown:
        d.prev_ev = e
        d.this_ev = e
    if e.buttonState == bsUp:
        d.checkFling()
        result = false
    if e.buttonState == bsUnknown:
        d.prev_ev = d.this_ev
        d.this_ev = e
