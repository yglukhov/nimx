import view
import event
export event
import system_logger
import typetraits

method onGestEvent*(d: GestureDetector, e: var Event) : bool {.base.} = discard

method name*(v: View): string {.base.} =
    result = "View"

method onTouchEv*(v: View, e: var Event): bool {.base.} =
    if not v.gestureDetectors.isNil:
        for d in v.gestureDetectors:
            let r = d.onGestEvent(e)
            result = result or r
    if not result:
        if e.buttonState == bsDown:
            if v.acceptsFirstResponder:
                discard v.makeFirstResponder()
    # echo v.name(), " onTouchEv ",e.buttonState," ",e.localPosition

method onInterceptTouchEv*(v: View, e: var Event): bool {.base.} =
    # echo v.name(), " onInterceptTouchEv ",e.localPosition
    discard

proc isMainWindow(v: View, e : var Event): bool =
    # echo v.superview.isNil
    result = v == e.window

proc processTouchEvent*(v: View, e : var Event): bool =
    if e.buttonState == bsDown and e.pointerId == 0:
        v.interceptEvents = false
        v.touchTarget = nil
        if v.subviews.isNil or v.subviews.len == 0:
            # echo v.name()," subs is nil"
            result = v.onTouchEv(e)
        else:
            if v.onInterceptTouchEv(e):
                # echo v.name()," intercepted events"
                v.interceptEvents = true
                result = v.onTouchEv(e)
            else:
                let localPosition = e.localPosition
                for i in countdown(v.subviews.len - 1, 0):
                    let s = v.subviews[i]
                    e.localPosition = localPosition - s.frame.origin + s.bounds.origin
                    # echo "local position = ",e.localPosition
                    # echo s.name()," s.bounds is :",s.bounds," frame is ",s.frame
                    if e.localPosition.inRect(s.bounds):
                        result = s.processTouchEvent(e)
                        if result:
                            v.touchTarget = s
                            break
                if not result:
                    e.localPosition = localPosition
                    result = v.onTouchEv(e)
    else:
        if v.subviews.isNil or v.subviews.len == 0:
            # single view
            if not v.isMainWindow(e):
                result = v.onTouchEv(e)
        else:
            # group view
            if v.interceptEvents:
                if not v.isMainWindow(e):
                    result = v.onTouchEv(e)
            else:
                if (not v.isMainWindow(e)) and v.onInterceptTouchEv(e):
                    v.interceptEvents = true
                    result = v.onTouchEv(e)
                else:
                    if not v.touchTarget.isNil:
                        let target = v.touchTarget
                        var localPosition = e.localPosition
                        e.localPosition = localPosition - target.frame.origin + target.bounds.origin
                        result = target.processTouchEvent(e)
                        e.localPosition = localPosition
                    else:
                        if not v.isMainWindow(e):
                            result = v.onTouchEv(e)
    if e.buttonState == bsUp and e.pointerId == 0 and v.isMainWindow(e):
        v.touchTarget = nil
        v.interceptEvents = false
