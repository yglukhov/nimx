import slider, animation
export slider

import composition, context, view_event_handling

type ScrollBar* = ref object of Slider
    mKnobSize: float # Knob size should vary between 0.0 and 1.0 depending on
                    # shown part of document in the clip view. E.g. if all of
                    # the document fits, then it should be 1.0. Half of the
                    # document is 0.5.
    trackingPos: Coord # Position of mouse coordinate (x or y depending on orientation) within knob

const minKnobSize = 0.05
method init*(s: ScrollBar, r: Rect) =
    procCall s.Slider.init(r)
    s.mKnobSize = 0.2

proc knobRect(s: ScrollBar): Rect =
    result = s.bounds
    if s.isHorizontal:
        result.size.width *= max(s.mKnobSize, minKnobSize)
        result.origin.x = max((s.bounds.width - result.width) * s.value, 3)
        if result.maxX > s.bounds.width - 3:
            result.size.width = s.bounds.width - result.x - 3
        result = inset(result, 0, 2)
    else:
        result.size.height *= max(s.mKnobSize, minKnobSize)
        result.origin.y = max((s.bounds.height - result.height) * s.value, 3)
        if result.maxY > s.bounds.height - 3:
            result.size.height = s.bounds.height - result.y - 3
        result = inset(result, 2, 0)

method draw*(s: ScrollBar, r: Rect) =
    let bezelRect = s.bounds.inset(1, 1)
    var radius = min(bezelRect.width, bezelRect.height) / 2
    let c = currentContext()
    c.fillColor = newGrayColor(0.85, 0.5)
    c.strokeColor = newGrayColor(0.5, 0.5)
    c.strokeWidth = 0.5
    c.drawRoundedRect(bezelRect, radius)

    let kr = s.knobRect()
    radius = min(kr.width, kr.height) / 2
    c.strokeWidth = 1
    c.fillColor = newColor(0.2, 0.2, 0.3, 0.5)
    c.strokeColor = newGrayColor(0.65, 0.5)
    c.drawRoundedRect(kr, radius)

proc `knobSize=`*(s: ScrollBar, v: float) =
    s.mKnobSize = v
    if s.mKnobSize < 0: s.mKnobSize = 0
    elif s.mKnobSize > 1: s.mKnobSize = 1

template knobSize*(s: ScrollBar): float = s.mKnobSize

method onTouchEv*(s: ScrollBar, e: var Event): bool =
    template pageUp() =
        s.value = s.value - s.mKnobSize
        s.sendAction()

    template pageDown() =
        s.value = s.value + s.mKnobSize
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
            let ew = s.bounds.width - kr.width
            s.value = if ew > 0: x / ew else: 0
        else:
            let y = e.localPosition.y - s.trackingPos
            let eh = s.bounds.height - kr.height
            s.value = if eh > 0: y / eh else: 0
        s.sendAction()
        result = true
    of bsUp:
        discard
