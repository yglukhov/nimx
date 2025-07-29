import strutils
import sample_registry
import nimx / [ view, font, context, button, text_field, slider, popup_button, layout ]

type FontsView = ref object of View
    curFont: Font
    caption: string
    showBaseline: bool
    curFontSize: float
    baseline: Baseline

# template createSlider(fv: FontsView, title: string, y: var Coord, fr, to: Coord, val: typed) =
#     let lb = newLabel(newRect(20, y, 120, 20))
#     lb.text = title & ":"
#     let s = Slider.new(newRect(140, y, 120, 20))
#     let ef = newTextField(newRect(280, y, 120, 20))
#     s.onAction do():
#         let v = fr + (to - fr) * s.value
#         ef.text = $v
#         val = v
#         fv.setNeedsDisplay()
#     ef.onAction do():
#         try:
#             let v = parseFloat(ef.text)
#             s.value = (v - fr) / (to - fr)
#             val = v
#             fv.setNeedsDisplay()
#         except:
#             discard
#     fv.addSubview(lb)
#     fv.addSubview(s)
#     fv.addSubview(ef)
#     y += 22

method init(v: FontsView, r: Rect) =
    procCall v.View.init(r)
    var baselineMenuItems: seq[string]
    for i in Baseline.low .. Baseline.high:
        baselineMenuItems.add($i)

    let minFontSize = 8.0
    let maxFontSize = 80.0

    v.makeLayout:
        - TextField as captionTf:
            text: "A Quick Brown $@#&¿"
            leading == super + 20
            top == super + 20
            trailing == super - 20
            height == 20
            onAction:
                v.caption = captionTf.text
                v.setNeedsDisplay()

        - Label:
            text: "Size:"
            top == prev.bottom + 10
            leading == prev
            height == 20
            width == 120

        - Slider as sizeSlider:
            leading == prev.trailing + 10
            top == prev
            height == prev
            width == 120
            onAction:
                v.curFontSize = minFontSize + (maxFontSize - minFontSize) * sizeSlider.value
                sizeTextField.text = $v.curFontSize
                v.setNeedsDisplay()

        - TextField as sizeTextField:
            leading == prev.trailing + 10
            top == prev
            height == prev
            width == 120
            onAction:
                try:
                    v.curFontSize = parseFloat(sizeTextField.text)
                    sizeSlider.value = (v.curFontSize - minFontSize) / (maxFontSize - minFontSize)
                    v.setNeedsDisplay()
                except:
                    discard

        - Checkbox as showBaselineChkBox:
            title: "Show baseline"
            leading == super + 20
            top == prev.bottom + 10
            width == 140
            height == 20
            onAction:
                v.showBaseline = showBaselineChkBox.boolValue
                v.setNeedsDisplay()

        - PopupButton as baselineSelector:
            items: baselineMenuItems
            leading == prev.trailing + 10
            top == prev
            height == prev
            width == 120
            onAction:
                v.baseline = Baseline(baselineSelector.selectedIndex)
                v.setNeedsDisplay()

    captionTf.sendAction()

    # let captionTf = newTextField(newRect(20, 20, r.width - 40, 20))
    # captionTf.autoresizingMask = { afFlexibleWidth, afFlexibleMaxY }
    # captionTf.text = "A Quick Brown $@#&¿"
    # captionTf.onAction do():
    #     v.caption = captionTf.text
    #     v.setNeedsDisplay()
    # v.addSubview(captionTf)
    # captionTf.sendAction()

    # var y = 44.Coord
    # v.createSlider("size", y, 8.0, 80.0, v.curFontSize)

    # let showBaselineBtn = newCheckbox(newRect(20, y, 120, 16))
    # showBaselineBtn.title = "Show baseline"
    # showBaselineBtn.onAction do():
    #     v.showBaseline = showBaselineBtn.boolValue
    #     v.setNeedsDisplay()

    # v.addSubview(showBaselineBtn)
    # y += 16 + 5

    # let baselineSelector = PopupButton.new(newRect(20, y, 120, 20))
    # var items = newSeq[string]()
    # for i in Baseline.low .. Baseline.high:
    #     items.add($i)
    # baselineSelector.items = items
    # baselineSelector.onAction do():
    #     v.baseline = Baseline(baselineSelector.selectedIndex)
    #     v.setNeedsDisplay()
    # v.addSubview(baselineSelector)

method draw(v: FontsView, r: Rect) =
    let c = currentContext()

    if v.curFont.isNil:
        v.curFont = systemFontOfSize(v.curFontSize)
    v.curFont.size = v.curFontSize

    let s = v.curFont.sizeOfString(v.caption)
    var origin = s.centerInRect(v.bounds)

    echo s, " ", v.bounds

    if v.showBaseline:
        c.fillColor = newGrayColor(0.5)
        c.drawRect(newRect(origin, newSize(s.width, 1)))

    c.fillColor = blackColor()
    let oldBaseline = v.curFont.baseline
    v.curFont.baseline = v.baseline
    c.drawText(v.curFont, origin, v.caption)
    v.curFont.baseline = oldBaseline

registerSample(FontsView, "Fonts")
