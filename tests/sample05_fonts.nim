import strutils
import sample_registry
import nimx / [ view, font, context, button, text_field, slider, popup_button, layout ]

type FontsView = ref object of View
  curFont: Font
  caption: string
  showBaseline: bool
  curFontSize: float
  baseline: Baseline

method init(v: FontsView) =
  procCall v.View.init()
  var baselineMenuItems: seq[string]
  for i in Baseline.low .. Baseline.high:
    baselineMenuItems.add($i)

  const minFontSize = 8.0
  const maxFontSize = 80.0

  v.curFontSize = 50

  v.makeLayout:
    - TextField as captionTf:
      text: "A Quick Brown $@#&¿"
      leading == super + 20
      top == super + 20
      trailing == super - 20
      height == 20
      continuous: true
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
      value: (v.curFontSize - minFontSize) / (maxFontSize - minFontSize)
      onAction:
        v.curFontSize = minFontSize + (maxFontSize - minFontSize) * sizeSlider.value
        sizeTextField.text = $v.curFontSize
        v.setNeedsDisplay()

    - TextField as sizeTextField:
      leading == prev.trailing + 10
      top == prev
      height == prev
      width == 120
      text: $v.curFontSize
      continuous: true
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
