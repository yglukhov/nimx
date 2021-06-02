import nimx / [ view, context, button ]
import math

type ExpandButton* = ref object of Button
    expanded*: bool
    onExpandAction*: proc(state: bool)

method init*(b: ExpandButton, w: Window, r: Rect) =
    procCall b.Button.init(w, r)

    b.enable()
    b.onAction() do():
        b.expanded = not b.expanded
        if not b.onExpandAction.isNil:
            b.onExpandAction(b.expanded)

proc newExpandButton*(w: Window, r: Rect): ExpandButton =
    result.new()
    result.init(w, r)

proc newExpandButton*(v: View, w: Window, r: Rect): ExpandButton =
    result = newExpandButton(w, r)
    v.addSubview(result)

method draw*(b: ExpandButton, r: Rect) =
    let c = b.window.gfxCtx
    c.fillColor = newColor(0.9, 0.9, 0.9)
    c.drawTriangle(r, if b.expanded: Coord(PI / 2.0) else: Coord(0))
