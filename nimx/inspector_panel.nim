import nimx.text_field
import nimx.scroll_view
import nimx.panel_view
import nimx.inspector_view

export panel_view

type InspectorPanel* = ref object of PanelView
    inspectorView: InspectorView

proc moveSubviewToBack(v, s: View) =
    let i = v.subviews.find(s)
    if i != -1:
        v.subviews.delete(i)
        v.subviews.insert(s, 0)

method init*(i: InspectorPanel, r: Rect) =
    procCall i.PanelView.init(r)
    i.collapsible = true
    i.collapsed = true
    let title = newLabel(newRect(22, 6, 96, 15))
    title.textColor = whiteColor()
    title.text = "Properties"
    i.addSubview(title)
    i.autoresizingMask = { afFlexibleMaxX }
    i.inspectorView = InspectorView.new(newRect(0, i.titleHeight, r.width, r.height - i.titleHeight))
    i.inspectorView.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}

    let sv = newScrollView(i.inspectorView)
    sv.horizontalScrollBar = nil
    sv.autoresizingMask = {afFlexibleWidth, afFlexibleHeight}
    sv.setFrameOrigin(newPoint(sv.frame.x, i.titleHeight))
    sv.setFrameSize(newSize(i.frame.width, i.contentHeight))

    i.addSubview(sv)
    i.moveSubviewToBack(sv)

proc setInspectedObject*[T](i: InspectorPanel, o: T) {.inline.} =
    i.inspectorView.setInspectedObject(o)
    i.contentHeight = i.inspectorView.frame.height
