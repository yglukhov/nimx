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

proc contentView(v: ScrollView): View =
    if v.subviews.len > 0:
        result = v.subviews[0]

method onScroll*(v: ScrollView, e: var Event): bool =
    var o = v.bounds.origin
    o += e.offset

    var contentSize = zeroSize
    let cv = v.contentView()
    if cv != nil:
        contentSize = cv.frame.size

    # Trim x
    if o.x < 0:
        o.x = 0
    elif contentSize.width - o.x < v.bounds.width:
        o.x = contentSize.width - v.bounds.width

    # Trim y
    if o.y < 0:
        o.y = 0
    elif contentSize.height - o.y < v.bounds.height:
        o.y = contentSize.height - v.bounds.height

    v.setBoundsOrigin(o)
    result = true

method subviewDidChangeDesiredSize*(v: ScrollView, sub: View, desiredSize: Size) =
    var boundsOrigin = v.bounds.origin
    var size = desiredSize
    if desiredSize.width < v.bounds.width:
        size.width = v.bounds.width
        boundsOrigin.x = 0
    if desiredSize.height < v.bounds.height:
        size.height = v.bounds.height
        boundsOrigin.y = 0

    v.setBoundsOrigin(boundsOrigin)
    sub.setFrameSize(size)

