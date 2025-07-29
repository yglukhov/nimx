import nimx / view
import nimx / meta_extensions / [ property_desc, visitors_gen, serializers_gen ]

type ClipView* = ref object of View

proc newClipView*(r: Rect): ClipView =
  result.new()
  result.init()

method clipType*(v: ClipView): ClipType = ctDefaultClip

proc enclosingClipView*(v: View): ClipView = v.enclosingViewOfType(ClipView)

registerClass(ClipView)
genVisitorCodeForView(ClipView)
genSerializeCodeForView(ClipView)
