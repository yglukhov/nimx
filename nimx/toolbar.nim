import nimx/[context, view_dragging_listener, split_view]

type Toolbar* = ref object of SplitView

method init*(v: Toolbar, r: Rect) =
  procCall v.SplitView.init(r)
  v.vertical = false
  v.resizable = false
  # v.leftMargin = 10
  # v.padding = 3
  # v.topMargin = 3
  # v.bottomMargin = 3
  # v.rightMargin = 3
  v.enableDraggingByBackground()

method draw*(view: Toolbar, rect: Rect) =
  let c = currentContext()
  c.strokeWidth = 2
  c.strokeColor = newGrayColor(0.6, 0.7)
  c.fillColor = newGrayColor(0.3, 0.7)
  c.drawRoundedRect(view.bounds, 5)
