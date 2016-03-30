import view
import types

type
    Linearlayout* = ref object of View
    LinearLayoutParams* = ref object of LayoutParams
        weight* : int

proc newLinearLayoutParams*(weight: int): LinearLayoutParams =
    result.new
    result.weight = weight

method layout*(lay: Linearlayout) =
    var cur: Point = newPoint(0,0)
    let mysize = lay.frame.size
    var weightsum = 0;
    for v in lay.subviews:
        if not v.layoutParams.isNil:
            let params = v.layoutParams
            let mp = LinearLayoutParams(params)
            if not mp.isNil:
                if mp.weight > 0:
                    weightsum = weightsum + mp.weight
    for v in lay.subviews:
        if not v.layoutParams.isNil:
            let params = v.layoutParams
            let mp = LinearLayoutParams(params)
            if not mp.isNil:
                if mp.weight > 0:
                    let viewSize = v.frame.size
                    let newWidth = mysize.width * (mp.weight/weightsum)
                    v.setFrame(newRect(cur, newSize(newWidth, viewSize.height)))
                    cur = newPoint(cur.x + newWidth,cur.y)
