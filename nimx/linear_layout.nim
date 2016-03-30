import view
import types

type LinearLyoutOrientation* = enum
    horizontal
    vertical

type
    Linearlayout* = ref object of View
        orientation* : LinearLyoutOrientation

    LinearLayoutParams* = ref object of LayoutParams
        weight* : int

proc newLinearLayout*(rect: Rect, orientation: LinearLyoutOrientation) : Linearlayout =
    result.new
    result.orientation = orientation
    result.init(rect)

proc newLinearLayoutParams*(weight: int): LinearLayoutParams =
    result.new
    result.weight = weight

proc getWeightSum(lay: Linearlayout) : int =
    result = 0
    for v in lay.subviews:
        if not v.layoutParams.isNil:
            let params = v.layoutParams
            let mp = LinearLayoutParams(params)
            if not mp.isNil:
                if mp.weight > 0:
                    result = result + mp.weight

proc layHorizontal(lay: Linearlayout) =
    var cur: Point = newPoint(0,0)
    let mysize = lay.frame.size
    var weightsum = lay.getWeightSum()
    for v in lay.subviews:
        if not v.layoutParams.isNil:
            let params = v.layoutParams
            let mp = LinearLayoutParams(params)
            if not mp.isNil:
                let viewSize = v.frame.size
                var newWidth = viewSize.width
                var newHeight = viewSize.height
                if mp.weight > 0:
                    newWidth = mysize.width * (mp.weight/weightsum)
                v.setFrame(newRect(cur, newSize(newWidth, newHeight)))
                cur = newPoint(cur.x + newWidth,cur.y)

proc layVertical(lay: Linearlayout) =
    var cur: Point = newPoint(0,0)
    let mysize = lay.frame.size
    var weightsum = lay.getWeightSum()
    for v in lay.subviews:
        if not v.layoutParams.isNil:
            let params = v.layoutParams
            let mp = LinearLayoutParams(params)
            if not mp.isNil:
                let viewSize = v.frame.size
                var newWidth = viewSize.width
                var newHeight = viewSize.height
                if mp.weight > 0:
                    newHeight = mysize.height * (mp.weight/weightsum)
                v.setFrame(newRect(cur, newSize(newWidth, newHeight)))
                cur = newPoint(cur.x,cur.y + newHeight)

method layout*(lay: Linearlayout) =
    case lay.orientation
    of horizontal:
        lay.layHorizontal()
    of vertical:
        lay.layVertical()
