import view
import context
export view

import event
import logging

type ScrollView = ref object of View


proc newScrollView*(r: Rect): ScrollView =
    result.new()
    result.init(r)

proc newScrollView*(v: View): ScrollView =
    # Create a scrollview by wrapping v into it
    result = newScrollView(v.frame)
    v.setFrameOrigin(zeroPoint)
    result.addSubview(v)

method clipType*(v: ScrollView): ClipType = ctDefaultClip

method onScroll*(v: ScrollView, e: var Event): bool =
    var o = v.bounds.origin
    o += e.offset
    v.setBoundsOrigin(o)
    result = true

method draw*(v: ScrollView, r: Rect) =
    let c = currentContext()
    c.fillColor = newColor(1.0, 0, 0)
    c.drawRect(v.bounds)

