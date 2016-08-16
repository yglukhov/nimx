import sample_registry

import nimx.view, nimx.linear_layout, nimx.button

import random

type SplitViewsSampleView = ref object of View

proc newSplitView(r: Rect, horizontal: bool): LinearLayout =
    result = LinearLayout.new(r)
    result.horizontal = horizontal
    result.autoresizingMask = {afFlexibleWidth, afFlexibleHeight}
    result.userResizeable = true

const colors = [
     newColor(1, 0, 0),
     newColor(0, 1, 0),
     newColor(0, 0, 1),
     newColor(1, 1, 0),
     newColor(0, 1, 1),
     newColor(1, 0, 1)
]

proc newPane(sz: Size): View

proc split(pane: View, horizontally: bool) =
    let s = pane.superview

    var sz = pane.frame.size
    if horizontally:
        sz.width /= 2
    else:
        sz.height /= 2

    if (s of LinearLayout) and LinearLayout(s).horizontal == horizontally:
        pane.setFrameSize(sz)
        s.insertSubviewAfter(newPane(sz), pane)
    else:
        let vl = newSplitView(pane.frame, horizontally)
        s.replaceSubview(pane, vl)
        pane.setFrameSize(sz)
        vl.addSubview(pane)
        vl.addSubview(newPane(sz))

proc newPane(sz: Size): View =
    result = View.new(newRect(0, 0, sz.width, sz.height))
    result.backgroundColor = random(colors)

    const buttonSize = 20
    let pane = result

    let h = Button.new(newRect(5, 5, buttonSize, buttonSize))
    h.title = ">"
    h.onAction do(): pane.split(true)
    result.addSubview(h)

    let v = Button.new(newRect(h.frame.maxX + 2, 5, buttonSize, buttonSize))
    v.title = "v"
    v.onAction do(): pane.split(false)
    result.addSubview(v)

    let x = Button.new(newRect(v.frame.maxX + 2, 5, buttonSize, buttonSize))
    x.title = "x"
    x.onAction do():
        var s = pane
        while not s.isNil and s.superview of LinearLayout and s.superview.subviews.len == 1:
            s = s.superview
        s.removeFromSuperview()

    result.addSubview(x)

method init(v: SplitViewsSampleView, r: Rect) =
    procCall v.View.init(r)
    let hl = newSplitView(v.bounds, true)
    let paneSize = newSize(v.bounds.width / 2, v.bounds.height)
    hl.addSubview(newPane(paneSize))
    hl.addSubview(newPane(paneSize))
    v.addSubview(hl)

registerSample(SplitViewsSampleView, "Split Views")
