import nimx/gesture_detector
import nimx/view
import nimx/event
import nimx/context

type DraggingScrollListener = ref object of OnScrollListener
    view: View
    start: Point

method onTapDown(ls: DraggingScrollListener, e: var Event) =
    ls.start = ls.view.frame.origin

method onScrollProgress(ls: DraggingScrollListener, dx, dy : float32, e : var Event) =
    ls.view.setFrameOrigin(ls.start + newPoint(dx, dy))

proc enableDraggingByBackground*(v: View) =
     var listener: DraggingScrollListener
     listener.new
     listener.view = v
     v.addGestureDetector(newScrollGestureDetector(listener))

type ResizingKnob = ref object of View

type ResizingScrollListener = ref object of OnScrollListener
    view: View
    originalSize: Size

method onTapDown(ls: ResizingScrollListener, e: var Event) =
    ls.originalSize = ls.view.superview.frame.size

method onScrollProgress(ls: ResizingScrollListener, dx, dy : float32, e : var Event) =
    let v = ls.view.superview
    v.setFrameSize(ls.originalSize + newSize(dx, dy))

method draw(k: ResizingKnob, r: Rect) =
    let c = currentContext()
    c.strokeWidth = 2
    c.strokeColor = newGrayColor(0.2, 0.7)
    let b = k.bounds
    template drawAtOffset(o: Coord) =
        c.drawLine(newPoint(b.width * o, b.height), newPoint(b.width, b.height * o))
    drawAtOffset(0)
    drawAtOffset(0.4)
    drawAtOffset(0.8)

proc enableViewResizing*(v: View) =
    const size = 20
    let resizingKnob = ResizingKnob.new(newRect(v.bounds.width - size, v.bounds.height - size, size, size))
    resizingKnob.autoresizingMask = {afFlexibleMinX, afFlexibleMinY}
    v.addSubview(resizingKnob)
    var listener: ResizingScrollListener
    listener.new()
    listener.view = resizingKnob
    resizingKnob.addGestureDetector(newScrollGestureDetector(listener))
