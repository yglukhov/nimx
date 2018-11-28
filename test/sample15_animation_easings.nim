import strutils
import sample_registry
import nimx / [ view, context, animation, window, button, progress_indicator, text_field, font, types ]
import nimx.editor.bezier_view


type AnimationEasing = ref object of View
    curvedRectX: Coord
    linearRectX: Coord

    progress: ProgressIndicator
    animationCurved: Animation
    animationLinear: Animation

proc createAnimation(v: AnimationEasing, curved: bool): Animation=
    var a = newAnimation()
    a.loopDuration = 1.0
    a.numberOfLoops = 1
    a.onAnimate = proc(p: float)=
        if curved:
            v.curvedRectX = interpolate(0.float, 450.float, p)
        else:
            v.linearRectX = interpolate(0.float, 450.float, p)
            v.progress.value = p

    result = a

method init*(v: AnimationEasing, r: Rect) =
    procCall v.View.init(r)

    v.animationLinear = v.createAnimation(false)
    v.animationCurved = v.createAnimation(true)

    discard newLabel(v, newPoint(100, 100), newSize(100, 10), "time =>")
    discard newLabel(v, newPoint(60, 150), newSize(10, 200), "^\n||\np\nr\no\ng\nr\ne\ns\ns")
    var bezierView = new(BezierView, newRect(90, 120, 250, 250))

    var bezierWp: array[4, float]
    var tfs = newSeq[TextField](4)

    let onTFChanged = proc(i: int):proc()=
        let index = i
        result = proc() =
            try:
                bezierWp[i] = parseFloat(tfs[index].text)
            except:
                bezierWp[i] = 0.0

            bezierView.p1 = bezierWp[0]
            bezierView.p2 = bezierWp[1]
            bezierView.p3 = bezierWp[2]
            bezierView.p4 = bezierWp[3]

    discard newLabel(v, newPoint(10, 20), newSize(10, 20), "bezier(")

    discard newLabel(v, newPoint(10, 50), newSize(500, 50), "To drag first point use left mouse button, second - right")

    for i in 0 .. 3:
        var tf1 = newTextField(newRect(70 * (i + 1).float, 20, 65, 20))
        tf1.text = "0.0"
        tf1.continuous = true
        tf1.onAction(onTFChanged(i))
        v.addSubview(tf1)
        tfs[i] = tf1

        if i != 3:
            discard newLabel(v, newPoint(70 * (i + 1).float + 62.5, 20), newSize(10, 20), ",")

    discard newLabel(v, newPoint(350, 20), newSize(10, 20), ")")

    let startStopButton = newButton(newRect(370, 20, 65, 20))
    startStopButton.title = "Go"
    startStopButton.onAction do():

        v.animationCurved.timingFunction = bezierTimingFunction(bezierWp[0], bezierWp[1], bezierWp[2], bezierWp[3])
        v.animationLinear.timingFunction = linear

        v.window.addAnimation(v.animationLinear)
        v.window.addAnimation(v.animationCurved)

    v.addSubview(startStopButton)

    bezierView.onAction do():
        bezierWp[0] = bezierView.p1
        bezierWp[1] = bezierView.p2
        bezierWp[2] = bezierView.p3
        bezierWp[3] = bezierView.p4

        for i, v in tfs:
            v.text = formatFloat(bezierWp[i], precision = 5)

    v.addSubview(bezierView)


    v.progress = ProgressIndicator.new(newRect(50, 400, 550, 20))
    v.addSubview(v.progress)

method draw(v: AnimationEasing, r: Rect) =
    let c = currentContext()
    c.strokeWidth = 2

    let offsetX = 50.0
    let offsetY = 400
    let font = systemFont()
    let cr = newRect(v.curvedRectX + offsetX, v.progress.frame.y + 30.0, 100, 50)
    let lr = newRect(v.linearRectX + offsetX, v.progress.frame.y + 90.0, 100, 50)

    c.fillColor = newColor(0.5, 0.7, 0.2)
    c.strokeColor = newColor(0.0, 0.0, 0.0)
    c.drawRoundedRect(cr, 20)

    c.fillColor = newColor(0.5, 0.5, 0.5)
    c.strokeColor = newColor(0.0, 0.0, 0.0)
    c.drawRoundedRect(lr, 20)

    c.fillColor = blackColor()
    c.strokeWidth = 1
    c.drawLine(newPoint(offsetX, v.progress.frame.y + 30.0), newPoint(offsetX, v.progress.frame.y + 140.0))
    c.drawLine(newPoint(600, v.progress.frame.y + 30.0), newPoint(600, v.progress.frame.y + 140.0))

    c.drawText(font, centerInRect(sizeOfString(font, "curved"), cr), "curved")
    c.drawText(font, centerInRect(sizeOfString(font, "linear"), lr), "linear")


registerSample(AnimationEasing, "AnimationEasing")
