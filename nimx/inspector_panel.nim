import ./[text_field, scroll_view, panel_view, inspector_view]

export panel_view

type InspectorPanel* = ref object of PanelView
  inspectorView: InspectorView
  mOnPropertyChanged: proc(name: string) {.gcsafe.}


proc moveSubviewToBack(v, s: View) =
  let i = v.subviews.find(s)
  if i != -1:
    v.subviews.delete(i)
    v.subviews.insert(s, 0)

proc onPropertyChanged*(i: InspectorPanel, cb: proc(name: string) {.gcsafe.}) =
  i.mOnPropertyChanged = cb

method init*(i: InspectorPanel, r: Rect) =
  i.draggable = false
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
  i.inspectorView.onPropertyChanged = proc(name: string) {.gcsafe.} =
    if not i.mOnPropertyChanged.isNil:
      i.mOnPropertyChanged(name)

  let sv = newScrollView(i.inspectorView)
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
