import view

type ClipView* = ref object of View

proc newClipView*(r: Rect): ClipView =
    result.new()
    result.init(r)
    result.autoresizingMask = { afFlexibleWidth, afFlexibleHeight }

method subviewDidChangeDesiredSize*(v: ClipView, sub: View, desiredSize: Size) =
    v.superview.subviewDidChangeDesiredSize(v, desiredSize)

method clipType*(v: ClipView): ClipType = ctDefaultClip

method isClipView(v: View): bool {.base.} = false
method isClipView(v: ClipView): bool = true

proc enclosingClipView*(v: View): ClipView =
    if not v.superview.isNil and v.superview.isClipView():
        v.superview.ClipView
    else:
        nil
