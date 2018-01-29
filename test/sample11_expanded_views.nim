import sample_registry
import strutils
import random

import nimx.view
import nimx.font
import nimx.context
import nimx.composition
import nimx.button
import nimx.autotest

import nimx.event
import nimx.expanding_view
import nimx.stack_view

type ExpandingSampleView = ref object of View
    welcomeFont: Font

method init(v: ExpandingSampleView, r: Rect) =
    procCall v.View.init(r)

    let stackView = newStackView(newRect(90,50, 300, 600))
    v.addSubview(stackView)

    for i in 0..4:
        let rand_y = rand(100 .. 400)
        let expView = newExpandingView(newRect(0, 0, 300, rand_y.Coord), true)
        expView.title = "newExpandedView " & $i
        stackView.addSubview(expView)

        for i in 0..4:
            let rand_y = rand(0 .. 300)
            let expView1 = newExpandingView(newRect(0, 0, 300, 10), true)
            expView1.title = "WOW " & $i
            expView.addContent(expView1)

            let testView = newView(newRect(0,0, 100, rand_y.Coord))
            testView.backgroundColor = newColor(0.2, 1.2, 0.2, 1.0)
            expView1.addContent(testView)
            discard newButton(testView, newPoint(10, 10), newSize(16, 16), "X")

method draw(v: ExpandingSampleView, r: Rect) =
    let c = currentContext()
    if v.welcomeFont.isNil:
        v.welcomeFont = systemFontOfSize(20)
    c.fillColor = blackColor()
    c.drawText(v.welcomeFont, newPoint(10, 5), "test")

registerSample(ExpandingSampleView, "ExpandingView")
