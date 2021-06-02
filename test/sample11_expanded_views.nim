import random
import sample_registry
import nimx / [ view, font, context, button, expanding_view, stack_view ]

type ExpandingSampleView = ref object of View
    welcomeFont: Font

method init(v: ExpandingSampleView, w: Window, r: Rect) =
    procCall v.View.init(w, r)

    let stackView = newStackView(w, newRect(90,50, 300, 600))
    v.addSubview(stackView)

    for i in 0..4:
        let rand_y = rand(100 .. 400)
        let expView = newExpandingView(w, newRect(0, 0, 300, rand_y.Coord), true)
        expView.title = "newExpandedView " & $i
        stackView.addSubview(expView)

        for i in 0..4:
            let rand_y = rand(0 .. 300)
            let expView1 = newExpandingView(w, newRect(0, 0, 300, 10), true)
            expView1.title = "WOW " & $i
            expView.addContent(expView1)

            let testView = newView(w, newRect(0,0, 100, rand_y.Coord))
            testView.backgroundColor = newColor(0.2, 1.2, 0.2, 1.0)
            expView1.addContent(testView)
            discard newButton(testView, w, newPoint(10, 10), newSize(16, 16), "X")

method draw(v: ExpandingSampleView, r: Rect) =
    template gfxCtx: untyped = v.window.gfxCtx
    template fontCtx: untyped = gfxCtx.fontCtx
    if v.welcomeFont.isNil:
        v.welcomeFont = systemFontOfSize(fontCtx, 20)
    gfxCtx.fillColor = blackColor()
    gfxCtx.drawText(v.welcomeFont, newPoint(10, 5), "test")

registerSample(ExpandingSampleView, "ExpandingView")
