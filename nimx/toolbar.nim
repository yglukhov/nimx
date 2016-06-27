import nimx.context
import nimx.view_dragging_listener
import nimx.linear_layout

type Toolbar* = ref object of LinearLayout

method init*(v: Toolbar, r: Rect) =
    procCall v.LinearLayout.init(r)
    v.horizontal = true
    v.leftMargin = 10
    v.padding = 3
    v.topMargin = 3
    v.bottomMargin = 3
    v.rightMargin = 3
    v.enableDraggingByBackground()

method draw*(view: Toolbar, rect: Rect) =
    let c = currentContext()
    c.strokeWidth = 2
    c.strokeColor = newGrayColor(0.6, 0.7)
    c.fillColor = newGrayColor(0.3, 0.7)
    c.drawRoundedRect(view.bounds, 5)
