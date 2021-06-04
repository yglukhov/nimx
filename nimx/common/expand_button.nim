import nimx / [ view, context, button ]
import math

type ExpandButton* = ref object of Button
    expanded*: bool
    onExpandAction*: proc(state: bool)

method init*(b: ExpandButton, gfx: GraphicsContext, r: Rect) =
    procCall b.Button.init(gfx, r)

    b.enable()
    b.onAction() do():
        b.expanded = not b.expanded
        if not b.onExpandAction.isNil:
            b.onExpandAction(b.expanded)

proc newExpandButton*(gfx: GraphicsContext, r: Rect): ExpandButton =
    result.new()
    result.init(gfx, r)

proc newExpandButton*(v: View, gfx: GraphicsContext, r: Rect): ExpandButton =
    result = newExpandButton(gfx, r)
    v.addSubview(result)

method draw*(b: ExpandButton, r: Rect) =
    template c: untyped = b.gfx
    c.fillColor = newColor(0.9, 0.9, 0.9)
    c.drawTriangle(r, if b.expanded: Coord(PI / 2.0) else: Coord(0))
