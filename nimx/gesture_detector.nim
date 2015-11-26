import view
import event
import view_event_handling
import system_logger
import app

template registerDetector*(d: GestureDetector, ev: var Event): stmt {.immediate.} =
    mainApplication().pushEventFilter do(e: var Event, c: var EventFilterControl) -> bool:
        if e.kind == etTouch:
            result = d.handleGesEvent(e)
            if e.buttonState == bsUp or not result:
                c = efcBreak
            else :
                c = efcContinue
    result = d.handleGesEvent(ev)

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


proc newTapGestureDetector*(listener : OnTapListener) : TapGestureDetector =
    new(result)
    result.tapListener = listener

proc newScrollGestureDetector*(listener : OnScrollListener) : ScrollDetector =
    new(result)
    result.scrollListener = listener

method onTouchGesEvent*(d: BaseGestureDetector, e: var Event) : bool =
    registerDetector(d, e)

method handleGesEvent*(d: ScrollDetector, e: var Event) : bool =
    result = true
    if e.pointerId != 0: result = false
    else:
        if e.isButtonDownEvent():
            d.last_position = e.position
        elif e.isButtonUpEvent():
            result = false
        else:
            if not d.scrollListener.isNil:
                d.scrollListener(e.position.x - d.last_position.x, e.position.y - d.last_position.y)
            d.last_position = e.position


method handleGesEvent*(d: TapGestureDetector, e: var Event) : bool =
    result = true
    if e.pointerId != 0: result = false
    else:
        if e.isButtonDownEvent():
            d.down_position = e.position
            d.down_timestamp = e.timestamp
        else:
            let timedelta = e.timestamp - d.down_timestamp
            if timedelta > 200'u32:
                result = false
            else:
                if e.isButtonUpEvent():
                    result = false
                    if not d.tapListener.isNil:
                        let dist = d.down_position.distanceTo(e.position)
                        if dist < 20:
                            d.tapListener(e.position)
