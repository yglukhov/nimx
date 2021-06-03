import view
export view

import view_event_handling
import nimx/gesture_detector
import types
import clip_view

type
    Adapter* = ref object of RootObj

    ListScrollListener = ref object of OnScrollListener
        start : Point
        view : HorizontalListView

    ViewWrapper = ref object
        v : View
        pos : int

    HorizontalListView* = ref object of ClipView
        adapter: Adapter
        items : seq[ViewWrapper]
        cleared : seq[ViewWrapper]
        dirty : bool
        dirtyBoundsOrigin : Point
        itemClick: proc(pos : int)

proc newViewWrapper(view: View, pos: int): ViewWrapper =
    result.new
    result.v = view
    result.pos = pos

method getCount*(a : Adapter): int {.base.} = discard
method getView*(a: Adapter, position: int, convertView : View): View {.base.} = discard

method setItemClickListener*(v: HorizontalListView, lis : proc(pos : int)) {.base.} =
    v.itemClick = lis

proc newHorListView*(gfx: GraphicsContext, r: Rect): HorizontalListView =
    result.new()
    result.items = @[]
    result.cleared = @[]
    result.init(gfx, r)

var offs = newPoint(0,0) # TODO: globals

proc getMinPos(v : HorizontalListView):ViewWrapper =
    if v.items.len > 0:
        var pos = v.items[0].pos
        result = v.items[0]
        for w in v.items:
            if w.pos < pos:
                result = w
                pos = w.pos

proc getMaxPos(v : HorizontalListView):ViewWrapper =
    if v.items.len > 0:
        var pos = v.items[0].pos
        result = v.items[0]
        for w in v.items:
            if w.pos > pos:
                result = w
                pos = w.pos

proc getClearedWrapper(v : HorizontalListView):ViewWrapper =
    if v.cleared.len>0:
        result = v.cleared[0]
        v.cleared.delete(0)

proc populateLeft(v : HorizontalListView, edgeLeft : ViewWrapper) =
    var sx = v.bounds.origin.x
    var cx = edgeLeft.v.frame.origin.x
    var pos : int = edgeLeft.pos - 1
    while cx > sx:
        if pos < 0:
            break
        var convert : View = nil
        var wr = v.getClearedWrapper()
        if not wr.isNil:
            convert = wr.v
        let view = v.adapter.getView(pos,convert)
        cx = cx - view.bounds.size.width
        view.setFrameOrigin(newPoint(cx,0))
        v.addSubview(view)
        if not wr.isNil:
            wr.v = view
            wr.pos = pos
        else:
            wr = newViewWrapper(view,pos)
        v.items.add(wr)
        pos = pos - 1

proc populateRight(v : HorizontalListView, edgeRight : ViewWrapper) =
    var cx = v.bounds.origin.x
    var fx = v.bounds.origin.x + v.bounds.size.width
    var pos = 0
    if not edgeRight.isNil:
        cx = edgeRight.v.frame.origin.x + edgeRight.v.frame.size.width
        pos = edgeRight.pos+1
    while cx < fx:
        if pos >= v.adapter.getCount():
            break
        var convert : View = nil
        var wr = v.getClearedWrapper()
        if not wr.isNil:
            convert = wr.v
        let view = v.adapter.getView(pos,convert)
        view.setFrameOrigin(newPoint(cx,0))
        cx = cx + view.bounds.size.width
        v.addSubview(view)
        if not wr.isNil:
            wr.v = view
            wr.pos = pos
        else:
            wr = newViewWrapper(view,pos)
        v.items.add(wr)
        pos = pos + 1

proc checkEdges(v : HorizontalListView, orig : Point) : Point =
    let o = orig
    result = o
    if o.x < 0:
        result = newPoint(0,0)
    if not v.adapter.isNil:
        let max = v.getMaxPos()
        let min = v.getMinPos()
        if (not max.isNil) and (not min.isNil):
            # echo "check 1"
            if max.pos >= v.adapter.getCount()-1:
                let vo = max.v.frame.origin
                let s = max.v.frame.size
                if vo.x < o.x + v.frame.size.width - s.width:
                    # echo "check 2 ",vo.x
                    if min.pos > 0:
                        result = newPoint(vo.x + s.width - v.frame.size.width,0)
                    else:
                        result = newPoint(0,0)


proc syncAdapterOnView(v : HorizontalListView) =
    var sx = v.bounds.origin.x
    let fx = v.bounds.size.width + sx
    # echo "x port is: ", sx, "  ", fx
    var i : int = 0
    while i < v.items.len:
        let vi = v.items[i]
        if vi.v.frame.intersect(v.bounds):
            # echo vi.pos," intersect "
            i = i+1
        else:
            vi.v.removeFromSuperview()
            v.items.delete(i)
            v.cleared.add(vi)
    let minPos = v.getMinPos()
    if not minPos.isNil:
        v.populateLeft(minPos)
    let maxPos = v.getMaxPos()
    v.populateRight(maxPos)
    # echo "cleared: ",v.cleared.len, " items: ", v.items.len

method setAdapter*(v : HorizontalListView, a : Adapter) {.base.} =
    v.adapter = a
    v.syncAdapterOnView

method draw*(view: HorizontalListView, rect: Rect) =
    procCall view.View.draw(rect)
    if view.dirty:
        let bo = view.checkEdges(view.dirtyBoundsOrigin)
        view.setBoundsOrigin(bo)
        view.syncAdapterOnView()
        view.dirty = false
        view.setNeedsDisplay()

method onTapDown*(lis : ListScrollListener, e : var Event) =
    lis.start = lis.view.bounds.origin

method onScrollProgress*(lis: ListScrollListener, dx, dy : float32, e : var Event) =
    let inv = newPoint(lis.start.x-dx,0)
    lis.view.dirtyBoundsOrigin = inv
    lis.view.dirty = true
    lis.view.setNeedsDisplay()

method onTapUp*(lis: ListScrollListener, dx, dy : float32, e : var Event) =
    discard

proc checkItemClick(v : HorizontalListView, p : Point) =
    let real = v.convertPointFromWindow(p) + v.bounds.origin
    for wrap in v.items:
        if real.inRect(wrap.v.frame):
            if not v.itemClick.isNil:
                v.itemClick(wrap.pos)

method init*(v: HorizontalListView, gfx: GraphicsContext, r: Rect) =
    procCall v.View.init(gfx, r)
    v.backgroundColor = newGrayColor(0.89)
    var sl : ListScrollListener
    new(sl)
    sl.view = v
    v.addGestureDetector(newScrollGestureDetector(sl))
    v.addGestureDetector(newTapGestureDetector do(tapPoint : Point):
        v.checkItemClick(tapPoint)
        )

method name*(v: HorizontalListView): string =
    result = "HorizontalListView"
