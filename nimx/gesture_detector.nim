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

    ScrollDetector* = ref object of GestureDetector

    OnTapListener* = proc(tapPoint : Point)
    TapGestureDetector* = ref object of BaseGestureDetector
        tapListener* : OnTapListener
        down_timestamp: uint32
        down_position: Point

proc newTapGestureDetector*(listener : OnTapListener) : TapGestureDetector =
    new(result)
    result.tapListener = listener

method onTouchGesEvent*(d: BaseGestureDetector, e: var Event) : bool =
    registerDetector(d, e)


method handleGesEvent*(sd: ScrollDetector, e: var Event) : bool =
    logi("ScrollDetector event X:" & $e.position.x & " state " & $e.buttonState)
    result = true

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
