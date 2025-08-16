import std/[strutils, tables, algorithm]

import ../[ view, text_field, matrixes, image, button, color_picker,
  context, portable_gl, layout, popup_button, font, property_visitor,
  numeric_text_field, system_logger, image_preview, drag_and_drop,
  render_to_image
]
import ../pasteboard/pasteboard_item
import ../assets/asset_loading
import ./propedit_registry
import variant


when defined(js):
  from dom import alert, window
elif not defined(android) and not defined(ios):
  import os_files/dialog

type
  NimxImageEditorDropDelegate* = ref object of DragDestinationDelegate
    callback: proc(i: Image) {.gcsafe.}

const nimxPbImage* = "nimx.pb.image"

method onDragEnter*(dd: NimxImageEditorDropDelegate, target: View, i: PasteboardItem) =
  if i.kind == nimxPbImage:
    target.backgroundColor.a = 0.5

method onDragExit*(dd: NimxImageEditorDropDelegate, target: View, i: PasteboardItem) =
  if i.kind == nimxPbImage:
    target.backgroundColor.a = 0.0

method onDrop*(dd: NimxImageEditorDropDelegate, target: View, i: PasteboardItem) =
  target.backgroundColor.a = 0.0
  if i.kind == nimxPbImage:
    loadAsset[Image]("file://" & i.data) do(image: Image, err: string):
      if image.isNil:
        echo "Can't load image from ", i.data
        return
      if not dd.callback.isNil:
        dd.callback(image)

template toStr(v: SomeFloat, precision: uint): string = formatFloat(v, ffDecimal, precision)
template toStr(v: SomeInteger): string = $v

template fromStr(v: string, t: var SomeFloat) = t = v.parseFloat()
template fromStr(v: string, t: var SomeInteger) = t = type(t)(v.parseInt())

proc newScalarPropertyView[T](setter: proc(s: T) {.gcsafe.}, getter: proc(): T {.gcsafe.}): PropertyEditorView =
  result = PropertyEditorView.new()
  result.makeLayout:
    - NumericTextField as tf:
      font: editorFont()
      frame == super
      height == editorRowHeight
      onAction:
        var v: T
        try:
          fromStr(tf.text, v)
          setter(v)
        except ValueError:
          discard

  when T is SomeFloat:
    tf.text = toStr(getter(), tf.precision)
  else:
    tf.text = toStr(getter())

proc newTextPropertyView(setter: proc(s: string) {.gcsafe.}, getter: proc(): string {.gcsafe.}): PropertyEditorView {.gcsafe.} =
  result = PropertyEditorView.new()
  result.makeLayout:
    - TextField as tf:
      frame == super
      height == editorRowHeight
      font: editorFont()
      text: getter()
      onAction:
        setter(tf.text)

proc newBoolPropertyView(setter: proc(s: bool) {.gcsafe.}, getter: proc(): bool {.gcsafe.} ): PropertyEditorView =
  result = PropertyEditorView.new()
  result.makeLayout:
    - Checkbox as check:
      # x == super.trailing - editorRowHeight
      x == super.x
      y == super.y
      width == editorRowHeight
      height == editorRowHeight
      height == super
  check.value = if getter(): 1 else: 0
  check.onAction do():
    setter(check.boolValue)

proc newVector2PropertyView(setter: proc(s: Vector2) {.gcsafe.}, getter: proc(): Vector2 {.gcsafe.}): PropertyEditorView =
  proc complexSetter() {.gcsafe.}
  result = PropertyEditorView.new()
  let val = getter()
  result.makeLayout:
    - NumericTextField as xComp:
      y == super.y
      x == super.x
      width == super * 0.5
      height == editorRowHeight
      height == super
      name: "#0"
      font: editorFont()
      text: toStr(val[0], xComp.precision)
      onAction:
        complexSetter()

    - NumericTextField as yComp:
      y == super.y
      x == prev.x + prev.width
      width == super * 0.5
      height == editorRowHeight
      name: "#1"
      font: editorFont()
      text: toStr(val[1], xComp.precision)
      onAction:
        complexSetter()

  proc complexSetter() {.gcsafe.} =
    try:
      var val = newVector2(xComp.text.parseFloat(), yComp.text.parseFloat())
      setter(val)
    except ValueError:
      return

proc newVector3PropertyView(setter: proc(s: Vector3) {.gcsafe.}, getter: proc(): Vector3 {.gcsafe.}): PropertyEditorView =
  proc complexSetter() {.gcsafe.}
  result = PropertyEditorView.new()
  let val = getter()
  result.makeLayout:
    - NumericTextField as xComp:
      y == super.y
      x == super.x
      width == super * 0.33
      height == editorRowHeight
      height == super
      name: "#0"
      font: editorFont()
      text: toStr(val[0], xComp.precision)
      onAction:
        complexSetter()

    - NumericTextField as yComp:
      y == super.y
      leading == prev.trailing
      width == prev
      height == prev
      name: "#1"
      font: editorFont()
      text: toStr(val[1], xComp.precision)
      onAction:
        complexSetter()

    - NumericTextField as zComp:
      y == super.y
      leading == prev.trailing
      width == prev
      height == prev
      name: "#2"
      font: editorFont()
      text: toStr(val[2], xComp.precision)
      onAction:
        complexSetter()

  proc complexSetter() {.gcsafe.} =
    try:
      var val = newVector3(xComp.text.parseFloat(), yComp.text.parseFloat(), zComp.text.parseFloat())
      setter(val)
    except ValueError:
      return

proc newVector4PropertyView(setter: proc(s: Vector4) {.gcsafe.}, getter: proc(): Vector4 {.gcsafe.}): PropertyEditorView =
  proc complexSetter() {.gcsafe.}
  result = PropertyEditorView.new()
  let val = getter()
  result.makeLayout:
    - NumericTextField as xComp:
      y == super.y
      x == super.x
      width == super * 0.25
      height == editorRowHeight
      name: "#0"
      font: editorFont()
      text: toStr(val[0], xComp.precision)
      onAction:
        complexSetter()

    - NumericTextField as yComp:
      y == super.y
      x == prev.x + prev.width
      width == super * 0.25
      height == editorRowHeight
      name: "#1"
      font: editorFont()
      text: toStr(val[1], xComp.precision)
      onAction:
        complexSetter()

    - NumericTextField as zComp:
      y == super.y
      x == prev.x + prev.width
      width == super * 0.25
      height == editorRowHeight
      name: "#2"
      font: editorFont()
      text: toStr(val[2], xComp.precision)
      onAction:
        complexSetter()

    - NumericTextField as wComp:
      y == super.y
      x == prev.x + prev.width
      width == super * 0.25
      height == editorRowHeight
      bottom == super
      name: "#3"
      font: editorFont()
      text: toStr(val[3], xComp.precision)
      onAction:
        complexSetter()

  proc complexSetter() {.gcsafe.} =
    try:
      var val = newVector4(xComp.text.parseFloat(), yComp.text.parseFloat(), zComp.text.parseFloat(), wComp.text.parseFloat())
      setter(val)
    except ValueError:
      return

proc newRectPropertyView(setter: proc(s: Rect) {.gcsafe.}, getter: proc(): Rect {.gcsafe.}): PropertyEditorView =
  newVector4PropertyView(
    proc(v: Vector4) {.gcsafe.} = setter(newRect(v.x, v.y, v.z, v.w)),
    proc(): Vector4 {.gcsafe.} =
      let s = getter()
      result = newVector4(s.x, s.y, s.width, s.height)
      )

proc newSizePropertyView(setter: proc(s: Size) {.gcsafe.}, getter: proc(): Size {.gcsafe.}): PropertyEditorView =
  newVector2PropertyView(
    proc(v: Vector2) {.gcsafe.} = setter(newSize(v.x, v.y)),
    proc(): Vector2 {.gcsafe.} =
      let s = getter()
      result = newVector2(s.width, s.height)
      )

proc newPointPropertyView(setter: proc(s: Point) {.gcsafe.}, getter: proc(): Point {.gcsafe.}): PropertyEditorView =
  newVector2PropertyView(
    proc(v: Vector2) = setter(newPoint(v.x, v.y)),
    proc(): Vector2 =
      let s = getter()
      result = newVector2(s.x, s.y)
      )


proc newColorPropertyView(setter: proc(s: Color) {.gcsafe.}, getter: proc(): Color {.gcsafe.}): PropertyEditorView =
  var r = new (PropertyEditorView)
  proc complexSetter() {.gcsafe.}
  proc pickerSetter(c: Color) {.gcsafe.}
  var val = getter()
  var colorPickerView: ColorPickerView
  var pickerSuperView: View
  var pickerPlaceholder: View

  colorPickerView = new (ColorPickerView)
  colorPickerView.makeLayout:
    frame == super
    height == 150
    backgroundColor: newGrayColor(0.5)
    color: val
    onAction:
      pickerSetter(colorPickerView.color)

  r.makeLayout:
    - Button as collapse:
      top == super
      leading == super
      width == editorRowHeight
      height == editorRowHeight
      title:"▶"
      hasBezel: false
      onAction:
        if not colorPickerView.superview.isNil:
          collapse.title = "▶"
          colorPickerView.removeFromSuperview()
          pickerSuperView.addSubview(pickerPlaceholder)
        else:
          collapse.title = "▼"
          pickerPlaceholder.removeFromSuperView()
          pickerSuperView.addSubview(colorPickerView)

    - View as cpvSuper:
      top == prev
      leading == prev.trailing
      trailing == super
      - View as cpvPlac:
        frame == super
        height == editorRowHeight

    - Label:
      text: "RGBA per component:"
      font: editorFont()
      top == prev.bottom
      leading == super
      trailing == super
      height == editorRowHeight

    - NumericTextField as xComp:
      top == prev.bottom
      bottom == super
      leading == super
      width == super * 0.25
      height == editorRowHeight
      name: "#0"
      font: editorFont()
      text: toStr(val[0], xComp.precision)
      onAction:
        complexSetter()

    - NumericTextField as yComp:
      top == prev
      width == prev
      leading == prev.trailing
      height == editorRowHeight
      name: "#1"
      font: editorFont()
      text: toStr(val[1], xComp.precision)
      onAction:
        complexSetter()

    - NumericTextField as zComp:
      top == prev
      width == prev
      leading == prev.trailing
      height == editorRowHeight
      name: "#2"
      font: editorFont()
      text: toStr(val[2], xComp.precision)
      onAction:
        complexSetter()

    - NumericTextField as wComp:
      top == prev
      width == prev
      leading == prev.trailing
      height == editorRowHeight
      name: "#3"
      font: editorFont()
      text: toStr(val[3], xComp.precision)
      onAction:
        complexSetter()

  pickerSuperView = cpvSuper
  pickerPlaceholder = cpvPlac

  proc complexSetter() {.gcsafe.} =
    try:
      var color = newColor(xComp.text.parseFloat(), yComp.text.parseFloat(), zComp.text.parseFloat(), wComp.text.parseFloat())
      setter(color)
      colorPickerView.color = color
    except ValueError:
      return

  proc pickerSetter(c: Color) {.gcsafe.} =
    xComp.text = toStr(c.r, xComp.precision)
    yComp.text = toStr(c.g, yComp.precision)
    zComp.text = toStr(c.b, zComp.precision)
    wComp.text = toStr(c.a, wComp.precision)
    setter(c)

  result = r

proc newEnumPropertyView(setter: proc(s: EnumValue) {.gcsafe.}, getter: proc(): EnumValue {.gcsafe.} ): PropertyEditorView =
  var val = getter()
  var items = newSeq[string]()
  for k, v in val.possibleValues:
    items.add(k)

  sort(items, system.cmp)
  var startVal = 0
  for i, v in items:
    if val.possibleValues[v] == val.curValue:
      startVal = i
      break

  var r = new(PropertyEditorView)
  r.makeLayout:
    - PopupButton as selector:
      frame == super
      height == editorRowHeight
      items: items
      selectedIndex: startVal
      onAction:
        val.curValue = val.possibleValues[selector.selectedItem()]
        setter(val)

  result = r

proc newFontPropertyView(setter: proc(s: Font) {.gcsafe.}, getter: proc(): Font {.gcsafe.}): PropertyEditorView =
  var val = getter()
  var items = getAvailableFonts()
  var fontSize = 16.0
  if not val.isNil:
    fontSize = val.size

  sort(items, system.cmp)
  var startVal = 0
  for i, v in items:
    if v == val.face:
      startVal = i
      break

  var r = new(PropertyEditorView)
  r.makeLayout:
    - PopupButton as selector:
      frame == super
      height == editorRowHeight
      items: items
      selectedIndex: startVal
      onAction:
        let val = newFontWithFace(selector.selectedItem(), fontSize)
        setter(val)

  result = r

when not defined(android) and not defined(ios):

  type
    ButtonImageView = ref object of Button
      originalImage: Image

  proc `onImageDropped=`(v: ButtonImageView, cb: proc(i: Image){.gcsafe.}) =
    v.dragDestination.NimxImageEditorDropDelegate.callback = cb

  method init*(v: ButtonImageView) =
    procCall v.Button.init()
    v.hasBezel = false
    v.dragDestination = new(NimxImageEditorDropDelegate)

  method draw*(v: ButtonImageView, r:Rect) =
    let c = currentContext()
    c.fillColor = v.backgroundColor
    c.drawRect(r)

    if v.originalImage.isNil: return
    if v.image.isNil and v.originalImage.size.width > v.frame.width or v.originalImage.size.height > v.frame.height:
      let imageSize = min(v.frame.width, v.frame.height)
      let scale = imageSize / max(v.originalImage.size.width, v.originalImage.size.height)
      let img = imageWithSize(newSize(imageSize, imageSize))
      img.draw:
        c.drawImage(v.originalImage, newRect(1, 1, v.originalImage.size.width * scale - 1, v.originalImage.size.height * scale - 1))
      v.image = img
    else:
      v.image = v.originalImage

    const offset = 2
    c.drawImage(v.image, newRect(r.x + offset, r.y + offset, r.width - offset*2, r.height - offset*2))

  proc newImagePropertyView(setter: proc(s: Image) {.gcsafe.}, getter: proc(): Image {.gcsafe.}): PropertyEditorView =
    var loadedImage = getter()
    proc imageDropped(i: Image) {.gcsafe.}
    let r = new(PropertyEditorView)
    r.makeLayout:
      - ButtonImageView as imagePlac:
        top == super
        leading == super
        width == 128
        height == 128
        hasBezel: false
        backgroundColor: newColor(0.222, 0.444, 0.666)
        originalImage: loadedImage
        onAction:
          if imagePlac.image.isNil:
            return

          var imagePreview = new(ImagePreview)
          imagePreview.image = imagePlac.originalImage
          imagePreview.popupAtCenterOfWindow()
        onImageDropped do(i: Image):
          imageDropped(i)
      - View:
        top == super
        bottom == super
        leading == prev.trailing
        trailing == super
        height == prev
        - Label:
          top == super
          leading == super
          trailing == super
          height == editorRowHeight
          text: "Size:"
        - Label as widthLabel:
          top == prev.bottom
          leading == prev
          trailing == prev
          height == prev
          text: "w:"
        - Label as heightLabel:
          top == prev.bottom
          leading == prev
          trailing == prev
          height == prev
          text: "h:"
        - Button as openBtn:
          # top == prev.bottom
          leading == prev
          trailing == super
          height == 20
          bottom == super.bottom
          title: "open image"
          onAction:
            when defined(js):
              alert(window, "Files can be opened only in native editor version")
            elif defined(emscripten):
              discard
            else:
              var di: DialogInfo
              di.title = "Select image"
              di.kind = dkOpenFile
              di.filters = @[(name:"PNG", ext:"*.png")]
              let path = di.show()
              echo "get path (", path, ")", path.len > 0
              if path.len > 0:
                var i: Image
                try:
                  i = imageWithContentsOfFile(path)
                  imagePlac.originalImage = i
                  imagePlac.image = nil
                  widthLabel.text = "w:" & $i.size.width
                  heightLabel.text = "h:" & $i.size.height
                except:
                  logi "Image could not be loaded: ", path
                if not i.isNil:
                  setter(i)
                  # if not pv.changeInspector.isNil:
                  #   pv.changeInspector()

    proc imageDropped(i: Image) {.gcsafe.} =
      imagePlac.originalImage = i
      imagePlac.image = nil
      widthLabel.text = "w:" & $i.size.width
      heightLabel.text = "h:" & $i.size.height
      setter(i)

    if not loadedImage.isNil:
      widthLabel.text = "w:" & $loadedImage.size.width
      heightLabel.text = "h:" & $loadedImage.size.height
    result = r

  registerPropertyEditor(newImagePropertyView)

registerPropertyEditor(newTextPropertyView)
registerPropertyEditor(newScalarPropertyView[Coord])
registerPropertyEditor(newScalarPropertyView[float])
registerPropertyEditor(newScalarPropertyView[float32])
registerPropertyEditor(newScalarPropertyView[int])
registerPropertyEditor(newScalarPropertyView[int16])
registerPropertyEditor(newScalarPropertyView[int32])
registerPropertyEditor(newVector2PropertyView)
registerPropertyEditor(newVector3PropertyView)
registerPropertyEditor(newVector4PropertyView)
registerPropertyEditor(newColorPropertyView)
registerPropertyEditor(newSizePropertyView)
registerPropertyEditor(newRectPropertyView)
registerPropertyEditor(newPointPropertyView)
registerPropertyEditor(newBoolPropertyView)
registerPropertyEditor(newEnumPropertyView)
registerPropertyEditor(newFontPropertyView)


template initPropertyEditor*(v: View, eo: untyped, propName: string, property: untyped)=
  var o = newVariant(eo)
  var visitor : PropertyVisitor
  visitor.requireName = true
  visitor.requireSetter = true
  visitor.requireGetter = true
  visitor.flags = { pfEditable }
  visitor.commit = proc() =
    v.addSubview(propertyEditorForProperty(o, visitor.name, visitor.setterAndGetter))

  visitor.visitProperty(propName, property)

# registerPropertyEditor(newScalarSeqPropertyView[float])
# registerPropertyEditor(newSeqPropertyView[TVector[4, Coord]])
# registerPropertyEditor(newSeqPropertyView[TVector[5, Coord]])

# proc newScalarSeqPropertyView[T](setter: proc(s: seq[T]) {.gcsafe.} , getter: proc(): seq[T] {.gcsafe.}): PropertyEditorView =
#   var val = getter()
#   var height = val.len() * 26 + 26
#   let pv = PropertyEditorView.new(newRect(0, 0, 208, height.Coord))

#   proc onValChange() =
#     setter(val)

#   proc onSeqChange() =
#     onValChange()
#     if not pv.changeInspector.isNil:
#       pv.changeInspector()

#   var y = 0.Coord
#   for i in 0 ..< val.len:
#     closureScope:
#       let index = i
#       let tf = newNumericTextField(newRect(0.Coord, y, 150, editorRowHeight))
#       tf.font = editorFont()
#       pv.addSubview(tf)
#       tf.text = toStr(val[i], tf.precision)
#       tf.onAction do():
#         if index < val.len:
#           fromStr(tf.text, val[index])
#           onValChange()

#       let removeButton = Button.new(newRect(153, y, editorRowHeight, editorRowHeight))
#       removeButton.title = "-"
#       pv.addSubview(removeButton)
#       removeButton.onAction do():
#         val.delete(index)
#         onSeqChange()

#       y += 18

#   let addButton = Button.new(newRect(153, y, editorRowHeight, editorRowHeight))
#   addButton.title = "+"
#   pv.addSubview(addButton)
#   addButton.onAction do():
#     val.add(0.0)
#     onSeqChange()

#   result = pv

# # proc newSeqPropertyView[I: static[int], T](setter: proc(s: seq[TVector[I, T]]), getter: proc(): seq[TVector[I, T]]): PropertyEditorView =
# proc newSeqPropertyView[T](setter: proc(s: seq[T]) {.gcsafe.}, getter: proc(): seq[T] {.gcsafe.}): PropertyEditorView =
#   var val = getter()
#   var height = val.len() * 26 + 26
#   let pv = PropertyEditorView.new(newRect(0, 0, 208, height.Coord))
#   const vecLen = high(T) + 1

#   proc onValChange() {.gcsafe.} =
#     setter(val)

#   proc onSeqChange() {.gcsafe.} =
#     onValChange()
#     if not pv.changeInspector.isNil:
#       pv.changeInspector()

#   var x = 0.Coord
#   var y = 0.Coord
#   for i in 0 ..< val.len:
#     closureScope:
#       let index = i
#       var vecVal = val[i]

#       x = 0.Coord
#       for j in 0 ..< vecLen:
#         closureScope:
#           let jIndex = j
#           let tf = newNumericTextField(newRect(x, y, 35, editorRowHeight))
#           tf.font = editorFont()
#           x += 37
#           pv.addSubview(tf)
#           tf.text = toStr(vecVal[j], tf.precision)
#           tf.onAction do():
#             if index < val.len:
#               val[index][jIndex] = tf.text.parseFloat()
#               onValChange()

#       let removeButton = Button.new(newRect(x, y, editorRowHeight, editorRowHeight))
#       removeButton.title = "-"
#       pv.addSubview(removeButton)
#       removeButton.onAction do():
#         val.delete(index)
#         onSeqChange()

#       y += editorRowHeight + 2

#   let addButton = Button.new(newRect(x, y, editorRowHeight, editorRowHeight))
#   addButton.title = "+"
#   pv.addSubview(addButton)
#   addButton.onAction do():
#     var newVal : TVector[vecLen, Coord]
#     val.add(newVal)
#     onSeqChange()

#   result = pv
