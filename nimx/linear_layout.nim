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

proc newLinearLayoutParams*(weight: int, width, height: int): LinearLayoutParams =
    result.new
    result.width = width
    result.height = height
    result.weight = weight
    result.layoutGravity = lgDefault

proc newLinearLayoutParams*(width, height: int): LinearLayoutParams =
    result = newLinearLayoutParams(0,width, height)

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
    for v in lay.subviews:
        let params = v.layoutParams
        let mp = LinearLayoutParams(params)
        let mw = v.measuredWidth
        let mh = v.measuredHeight
        case params.layoutGravity
        of lgTop:
            discard
        else:
            discard
        v.setFrame(newRect(cur, newSize(float(mw), float(mh))))
        cur = newPoint(cur.x + float(mw),cur.y)

proc layVertical(lay: Linearlayout) =
    var cur: Point = newPoint(0,0)
    for v in lay.subviews:
        let params = v.layoutParams
        let mp = LinearLayoutParams(params)
        let mw = v.measuredWidth
        let mh = v.measuredHeight
        case params.layoutGravity
        of lgTop:
            discard
        else:
            discard
        v.setFrame(newRect(cur, newSize(float(mw), float(mh))))
        cur = newPoint(cur.x,cur.y+float(mh))

method layout*(lay: Linearlayout) =
    case lay.orientation
    of horizontal:
        lay.layHorizontal()
    of vertical:
        lay.layVertical()

proc measureHorizontal(lay: Linearlayout, mWidth, mHeight: int) =
    var chW = mWidth
    if lay.layoutParams.width > 0:
        chW = lay.layoutParams.width
    var chH = mHeight
    if lay.layoutParams.height > 0:
        chH = lay.layoutParams.height
    var maxW = 0
    var maxH = 0
    var usedW = 0
    let weightSum = lay.getWeightSum()
    for v in lay.subviews:
        let params = LinearLayoutParams(v.layoutParams)
        if params.weight > 0:
            v.measure(int(chW * params.weight/weightSum),chH)
        else:
            v.measure(chW,chH)
        let mw = v.measuredWidth
        usedW = usedW + mw
        let mh = v.measuredHeight
        if mw > maxW:
            maxW = mw
        if mh > maxH:
            maxH = mh
        if params.weight <= 0:
            chW = chW - mw

    var w,h : int

    case lay.layoutParams.width
    of WRAP_CONTENT:
        w = usedW
    of MATCH_PARENT:
        w = mWidth
    else:
        w = lay.layoutParams.width

    case lay.layoutParams.height
    of WRAP_CONTENT:
        h = maxH

    of MATCH_PARENT:
        h = mHeight
    else:
        h = lay.layoutParams.height
    lay.measuredWidth = w
    lay.measuredHeight = h

proc measureVertical(lay: Linearlayout, mWidth, mHeight: int) =
    var chW = mWidth
    if lay.layoutParams.width > 0:
        chW = lay.layoutParams.width
    var chH = mHeight
    if lay.layoutParams.height > 0:
        chH = lay.layoutParams.height
    var maxW = 0
    var maxH = 0
    var usedH = 0
    let weightSum = lay.getWeightSum()
    for v in lay.subviews:
        let params = LinearLayoutParams(v.layoutParams)
        if params.weight > 0:
            v.measure(chW,int(chH * params.weight/weightSum))
        else:
            v.measure(chW,chH)
        let mw = v.measuredWidth
        let mh = v.measuredHeight
        usedH = usedH + mh
        if mw > maxW:
            maxW = mw
        if mh > maxH:
            maxH = mh
        if params.weight <= 0:
            chH = chH - mh

    var w,h : int

    case lay.layoutParams.width
    of WRAP_CONTENT:
        w = maxW
    of MATCH_PARENT:
        w = mWidth
    else:
        w = lay.layoutParams.width

    case lay.layoutParams.height
    of WRAP_CONTENT:
        h = usedH

    of MATCH_PARENT:
        h = mHeight
    else:
        h = lay.layoutParams.height
    lay.measuredWidth = w
    lay.measuredHeight = h

method measure*(lay: Linearlayout, mWidth, mHeight: int) =
    case lay.orientation
    of horizontal:
        lay.measureHorizontal(mWidth, mHeight)
    of vertical:
        lay.measureVertical(mWidth, mHeight)
