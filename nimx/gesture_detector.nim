import view
import event
import view_event_handling
import system_logger
import app

method handleGesEvent*(d: GestureDetector, e: var Event, c: var EventFilterControl) : bool {.base.} = discard

template registerDetector*(d: GestureDetector, ev: var Event): stmt {.immediate.} =
    mainApplication().pushEventFilter do(e: var Event, c: var EventFilterControl) -> bool:
        if e.kind == etTouch:
            result = d.handleGesEvent(e, c)
    var con = efcContinue
    result = d.handleGesEvent(ev, con)

type
    BaseGestureDetector* = ref object of GestureDetector

    OnScrollListener* = proc(dx,dy : float32)
    ScrollDetector* = ref object of BaseGestureDetector
        scrollListener* : OnScrollListener
        last_position : Point

    OnTapListener* = proc(tapPoint : Point)
    TapGestureDetector* = ref object of BaseGestureDetector
        tapListener* : OnTapListener
        down_timestamp: uint32
        down_position: Point

    OnZoomListener* = ref object of RootObj
    ZoomGestureDetector* = ref object of BaseGestureDetector
        last_distance : float32
        last_zoom : float32
        pointers : seq[Event]
        listener : OnZoomListener
        firing : bool

method onZoomStart*(l: OnZoomListener) {.base.} = discard
method onZoomProgress*(l: OnZoomListener, scale : float32) {.base.} = discard
method onZoomFinish*(l: OnZoomListener) {.base.} = discard


proc newTapGestureDetector*(listener : OnTapListener) : TapGestureDetector =
    new(result)
    result.tapListener = listener

proc newScrollGestureDetector*(listener : OnScrollListener) : ScrollDetector =
    new(result)
    result.scrollListener = listener

proc newZoomGestureDetector*(listener : OnZoomListener) : ZoomGestureDetector =
    new(result)
    result.pointers = @[]
    result.listener = listener
    result.last_zoom = 1.0'f32
    result.firing = false

method onTouchGesEvent*(d: BaseGestureDetector, e: var Event) : bool =
    registerDetector(d, e)

method handleGesEvent*(d: ScrollDetector, e: var Event, c: var EventFilterControl) : bool =
    result = false
    if e.pointerId != 0: c = efcBreak
    else:
        if e.isButtonDownEvent():
            d.last_position = e.position
        elif e.isButtonUpEvent():
            c = efcBreak
        else:
            if not d.scrollListener.isNil:
                d.scrollListener(e.position.x - d.last_position.x, e.position.y - d.last_position.y)
            d.last_position = e.position


method handleGesEvent*(d: TapGestureDetector, e: var Event, c: var EventFilterControl) : bool =
    result = false
    if e.pointerId != 0: c = efcBreak
    else:
        if e.isButtonDownEvent():
            d.down_position = e.position
            d.down_timestamp = e.timestamp
        else:
            let timedelta = e.timestamp - d.down_timestamp
            if timedelta > 200'u32:
                c = efcBreak
            else:
                if e.isButtonUpEvent():
                    c = efcBreak
                    if not d.tapListener.isNil:
                        let dist = d.down_position.distanceTo(e.position)
                        if dist < 20:
                            d.tapListener(e.position)

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



method handleGesEvent*(d: ZoomGestureDetector, e: var Event, c: var EventFilterControl) : bool =
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
            c = efcBreak
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
