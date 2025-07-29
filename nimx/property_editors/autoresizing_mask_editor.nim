import nimx/property_visitor
import nimx/numeric_text_field
import nimx/popup_button
import nimx/linear_layout

import nimx/property_editors/propedit_registry

import variant

proc newAutoresizingMaskPropertyView(setter: proc(s: set[AutoresizingFlag]) {.gcsafe.}, getter: proc(): set[AutoresizingFlag] {.gcsafe.}): PropertyEditorView =
  result = PropertyEditorView.new(newRect(0, 0, 208, editorRowHeight))

  let horLayout = newHorizontalLayout(newRect(0, 0, 208, editorRowHeight))
  horLayout.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
  result.addSubview(horLayout)

  var val = getter()
  let horEdit = PopupButton.new(newRect(0, 0, 40, editorRowHeight))
  horEdit.items = @["flexible left", "flexible width", "flexible right"]
  horEdit.onAction do():
    var newFlag = afFlexibleMaxX
    case horEdit.selectedIndex
    of 0: newFlag = afFlexibleMinX
    of 1: newFlag = afFlexibleWidth
    else: discard
    val = val - {afFlexibleMaxX, afFlexibleMinX, afFlexibleWidth} + {newFlag}
    setter(val)

  if afFlexibleMinX in val:
    horEdit.selectedIndex = 0
  elif afFlexibleWidth in val:
    horEdit.selectedIndex = 1
  else:
    horEdit.selectedIndex = 2

  horLayout.addSubview(horEdit)

  let vertEdit = PopupButton.new(newRect(40, 0, 40, editorRowHeight))
  vertEdit.items = @["flexible top", "flexible height", "flexible bottom"]
  vertEdit.selectedIndex = 0
  vertEdit.onAction do():
    var newFlag = afFlexibleMaxY
    case vertEdit.selectedIndex
    of 0: newFlag = afFlexibleMinY
    of 1: newFlag = afFlexibleHeight
    else: discard
    val = val - {afFlexibleMaxY, afFlexibleMinY, afFlexibleHeight} + {newFlag}
    setter(val)

  if afFlexibleMinY in val:
    vertEdit.selectedIndex = 0
  elif afFlexibleHeight in val:
    vertEdit.selectedIndex = 1
  else:
    vertEdit.selectedIndex = 2

  horLayout.addSubview(vertEdit)

registerPropertyEditor(newAutoresizingMaskPropertyView)
