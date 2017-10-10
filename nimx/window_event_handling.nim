import types
import abstract_window
import event
import view_event_handling
import view_event_handling_new
import drag_and_drop

proc propagateEventThroughResponderChain(w: Window, e: var Event): bool =
    var r = w.firstResponder
    while not result and not r.isNil and r != w:
        result = r.processKeyboardEvent(e)
        r = r.superview
    if not result:
        result = w.processKeyboardEvent(e)

proc getOtherResponders(v: View, exceptV: View, responders: var seq[View]) =
    for sv in v.subviews:
        if sv != exceptV:
            if sv.acceptsFirstResponder():
                responders.add sv
            sv.getOtherResponders(exceptV, responders)

proc findNearestNextResponder(fromX: float, fromY: float, responders: seq[View], forward: bool): View =
    let sign: float = if forward: 1 else: -1
    var bestDH: float = Inf
    var bestDV: float = Inf
    var bestResponder: View
    for responder in responders:
        let responderRect = responder.convertRectToWindow(responder.bounds)
        var dH = (responderRect.minX - fromX) * sign
        var dV = (responderRect.minY - fromY) * sign
        if dV > 0  or  (dV == 0 and dH > 0):
            if dV < bestDV  or  (dV == bestDV and dH < bestDH):
                bestResponder = responder
                bestDH = dH
                bestDV = dV
    return bestResponder

method onKeyDown*(w: Window, e: var Event): bool =
    if e.keyCode == VirtualKey.Tab:
        let forward = not e.modifiers.anyShift()
        var curResp = w.firstResponder
        let firstRespRect = w.firstResponder.convertRectToWindow(w.firstResponder.bounds)
        var nextResponder: View

        while nextResponder.isNil and curResp != w:
            var responders: seq[View] = @[]
            getOtherResponders(curResp.superview, curResp, responders)
            if responders.len > 0:
                nextResponder = findNearestNextResponder(firstRespRect.minX, firstRespRect.minY, responders, forward)
            curResp = curResp.superview

        if nextResponder.isNil:
            var responders: seq[View] = @[]
            getOtherResponders(w, w.firstResponder, responders)
            if forward:
                nextResponder = findNearestNextResponder(w.bounds.minX, w.bounds.minY, responders, forward)
            else:
                nextResponder = findNearestNextResponder(w.bounds.maxX, w.bounds.maxY, responders, forward)

        if not nextResponder.isNil():
            discard w.makeFirstResponder(nextResponder)

        return true

method handleEvent*(w: Window, e: var Event): bool {.base.} =
    case e.kind:
        of etScroll:
            result = w.processMouseWheelEvent(e)
        of etMouse, etTouch:
            currentDragSystem().processDragEvent(e)
            result = w.processTouchEvent(e)
        of etKeyboard:
            result = w.propagateEventThroughResponderChain(e)
        of etTextInput:
            result = w.propagateEventThroughResponderChain(e)
        of etWindowResized:
            result = true
            w.onResize(newSize(e.position.x, e.position.y))
            w.drawWindow()
        else:
            result = false
