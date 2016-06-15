import slider
export slider

import composition
import context
import font
import view_event_handling
import app

type ScrollBar* = ref object of Slider
    knobSize: float # Knob size should vary between 0.0 and 1.0 depending on
                    # shown part of document in the clip view. E.g. if all of
                    # the document fits, then it should be 1.0. Half of the
                    # document is 0.5.
    trackingPos: Coord # Position of mouse coordinate (x or y depending on orientation) within knob

method init*(s: ScrollBar, r: Rect) =
    procCall s.Slider.init(r)
    s.knobSize = 0.2

proc knobRect(s: ScrollBar): Rect =
    result = s.bounds
    if s.isHorizontal:
        result.size.width *= s.knobSize
        result.origin.x = (s.bounds.width - result.width) * s.value
        result = inset(result, 0, 1)
    else:
        result.size.height *= s.knobSize
        result.origin.y = (s.bounds.height - result.height) * s.value
        result = inset(result, 1, 0)

method draw*(s: ScrollBar, r: Rect) =
    var radius = min(s.bounds.width, s.bounds.height) / 2
    let c = currentContext()
    c.fillColor = newGrayColor(0.85, 0.5)
    c.strokeColor = newGrayColor(0.5, 0.5)
    c.strokeWidth = 0.5
    c.drawRoundedRect(s.bounds, radius)

    let kr = s.knobRect()
    radius = min(kr.width, kr.height) / 2
    c.strokeWidth = 1
    c.fillColor = newGrayColor(0.8, 0.8)
    c.strokeColor = newGrayColor(0.65, 0.5)
    c.drawRoundedRect(kr, radius)

method onTouchEv*(s: ScrollBar, e: var Event): bool =
    template pageUp() =
        s.value = s.value - s.knobSize
        s.sendAction()

    template pageDown() =
        s.value = s.value + s.knobSize
        s.sendAction()

    let kr = s.knobRect()
    case e.buttonState
    of bsDown:
        if e.localPosition.inRect(kr):
            if s.isHorizontal:
                s.trackingPos = e.localPosition.x - kr.x
            else:
                s.trackingPos = e.localPosition.y - kr.y
            result = true
        else:
            if s.isHorizontal:
                if e.localPosition.x < kr.x:
                    pageUp()
                else:
                    pageDown()
            else:
                if e.localPosition.y < kr.y:
                    pageUp()
                else:
                    pageDown()
    of bsUnknown:
        if s.isHorizontal:
            let x = e.localPosition.x - s.trackingPos
            s.value = x / (s.bounds.width - kr.width)
        else:
            let y = e.localPosition.y - s.trackingPos
            s.value = y / (s.bounds.height - kr.height)
        s.sendAction()
        result = true
    of bsUp:
        discard
