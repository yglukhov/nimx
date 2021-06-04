import nimx/text_field
import nimx/scroll_view
import nimx/panel_view
import nimx/inspector_view

export panel_view

type InspectorPanel* = ref object of PanelView
    inspectorView: InspectorView
    mOnPropertyChanged: proc(name: string)


proc moveSubviewToBack(v, s: View) =
    let i = v.subviews.find(s)
    if i != -1:
        v.subviews.delete(i)
        v.subviews.insert(s, 0)

proc onPropertyChanged*(i: InspectorPanel, cb: proc(name: string)) =
    i.mOnPropertyChanged = cb

method init*(i: InspectorPanel, gfx: GraphicsContext, r: Rect) =
    i.draggable = false
    procCall i.PanelView.init(gfx, r)
    i.collapsible = true
    i.collapsed = true
    let title = newLabel(gfx, newRect(22, 6, 96, 15))
    title.textColor = whiteColor()
    title.text = "Properties"
    i.addSubview(title)
    i.autoresizingMask = { afFlexibleMaxX }
    i.inspectorView = InspectorView.new(gfx, newRect(0, i.titleHeight, r.width, r.height - i.titleHeight))
    i.inspectorView.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    i.inspectorView.onPropertyChanged = proc(name: string) =
        if not i.mOnPropertyChanged.isNil:
            i.mOnPropertyChanged(name)

    let sv = newScrollView(gfx, i.inspectorView)
    sv.horizontalScrollBar = nil
    sv.autoresizingMask = {afFlexibleWidth, afFlexibleHeight}
    sv.setFrameOrigin(newPoint(sv.frame.x, i.titleHeight))
    sv.setFrameSize(newSize(i.frame.width, i.contentHeight))

    i.addSubview(sv)
    i.moveSubviewToBack(sv)

proc setInspectedObject*[T](i: InspectorPanel, o: T) {.inline.} =
    i.inspectorView.setInspectedObject(o)
    i.collapsed = o.isNil
    i.contentHeight = i.inspectorView.frame.height
