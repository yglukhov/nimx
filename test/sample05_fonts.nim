import strutils

import sample_registry

import nimx.view
import nimx.font
import nimx.context
import nimx.button
import nimx.text_field
import nimx.slider

type FontsView = ref object of View
    curFont: Font
    caption: string
    showBaseline: bool
    curFontSize: float
    curFontGamma: float
    curFontBase: float


template createSlider(fv: FontsView, title: string, y: var Coord, fr, to: Coord, val: typed) =
    let lb = newLabel(newRect(20, y, 120, 20))
    lb.text = title & ":"
    let s = Slider.new(newRect(140, y, 120, 20))
    let ef = newTextField(newRect(280, y, 120, 20))
    s.onAction do():
        let v = fr + (to - fr) * s.value
        ef.text = $v
        val = v
        fv.setNeedsDisplay()
    ef.onAction do():
        try:
            let v = parseFloat(ef.text)
            s.value = (v - fr) / (to - fr)
            val = v
            fv.setNeedsDisplay()
        except:
            discard
    fv.addSubview(lb)
    fv.addSubview(s)
    fv.addSubview(ef)
    y += 22

method init(v: FontsView, r: Rect) =
    procCall v.View.init(r)
    let captionTf = newTextField(newRect(20, 20, r.width - 40, 20))
    captionTf.autoresizingMask = { afFlexibleWidth, afFlexibleMaxY }
    captionTf.text = "A Quick Brown $@#&¿"
    captionTf.onAction do():
        v.caption = captionTf.text
        v.setNeedsDisplay()
    v.addSubview(captionTf)
    captionTf.sendAction()

    var y = 44.Coord
    v.createSlider("size", y, 8.0, 80.0, v.curFontSize)
    v.createSlider("gamma", y, 0.0, 4.0, v.curFontGamma)
    v.createSlider("base", y, 0.0, 4.0, v.curFontBase)

    discard """
    let sizeTf = newTextField(newRect(20, 44, 120, 20))
    sizeTf.text = "64"
    sizeTf.onAction do():
        try:
            v.curFontSize = parseFloat(sizeTf.text)
            v.curFont = nil
        except:
            discard

    v.addSubview(sizeTf)

    let showBaselineBtn = newCheckbox(newRect(20, 66, 120, 16))
    showBaselineBtn.title = "Show baseline"
    showBaselineBtn.onAction do():
        v.showBaseline = showBaselineBtn.boolValue
        v.setNeedsDisplay()

    v.addSubview(showBaselineBtn)

    sizeTf.sendAction()
    """


method draw(v: FontsView, r: Rect) =
    let c = currentContext()

    if v.curFont.isNil:
        v.curFont = systemFontOfSize(v.curFontSize)
    v.curFont.size = v.curFontSize
    if v.curFontGamma > 0.00001:
        v.curFont.gamma = v.curFontGamma
    if v.curFontBase > 0.00001:
        v.curFont.base = v.curFontBase

    let s = v.curFont.sizeOfString(v.caption)
    let origin = s.centerInRect(v.bounds)

    if v.showBaseline:
        c.fillColor = newGrayColor(0.5)
        c.drawRect(newRect(origin, newSize(300, 1)))

    c.fillColor = blackColor()
    c.drawText(v.curFont, origin, v.caption)

registerSample "Fonts", FontsView.new(newRect(0, 0, 100, 100))
