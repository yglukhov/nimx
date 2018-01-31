import strutils
import sample_registry
import nimx / [ view, font, context, button, text_field, slider, popup_button ]

type FontsView = ref object of View
    curFont: Font
    caption: string
    showBaseline: bool
    curFontSize: float
    baseline: Baseline

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

    let showBaselineBtn = newCheckbox(newRect(20, y, 120, 16))
    showBaselineBtn.title = "Show baseline"
    showBaselineBtn.onAction do():
        v.showBaseline = showBaselineBtn.boolValue
        v.setNeedsDisplay()

    v.addSubview(showBaselineBtn)
    y += 16 + 5

    let baselineSelector = PopupButton.new(newRect(20, y, 120, 20))
    var items = newSeq[string]()
    for i in Baseline.low .. Baseline.high:
        items.add($i)
    baselineSelector.items = items
    baselineSelector.onAction do():
        v.baseline = Baseline(baselineSelector.selectedIndex)
        v.setNeedsDisplay()
    v.addSubview(baselineSelector)

method draw(v: FontsView, r: Rect) =
    let c = currentContext()

    if v.curFont.isNil:
        v.curFont = systemFontOfSize(v.curFontSize)
    v.curFont.size = v.curFontSize

    let s = v.curFont.sizeOfString(v.caption)
    var origin = s.centerInRect(v.bounds)

    if v.showBaseline:
        c.fillColor = newGrayColor(0.5)
        c.drawRect(newRect(origin, newSize(s.width, 1)))

    c.fillColor = blackColor()
    let oldBaseline = v.curFont.baseline
    v.curFont.baseline = v.baseline
    c.drawText(v.curFont, origin, v.caption)
    v.curFont.baseline = oldBaseline

registerSample(FontsView, "Fonts")
