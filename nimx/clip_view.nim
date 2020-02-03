import view

type ClipView* = ref object of View

proc newClipView*(r: Rect): ClipView =
    result.new()
    result.init(r)
    result.autoresizingMask = { afFlexibleWidth, afFlexibleHeight }

method subviewDidChangeDesiredSize*(v: ClipView, sub: View, desiredSize: Size) =
    v.superview.subviewDidChangeDesiredSize(v, desiredSize)

method clipType*(v: ClipView): ClipType = ctDefaultClip

proc enclosingClipView*(v: View): ClipView = v.enclosingViewOfType(ClipView)

registerClass(ClipView)
