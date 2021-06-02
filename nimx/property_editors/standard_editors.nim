import strutils
import tables
import algorithm

import nimx/view
import nimx/text_field
import nimx/matrixes
import nimx/image
import nimx/button
import nimx/color_picker
import nimx/context
import nimx/portable_gl
import nimx/popup_button
import nimx/font
import nimx/linear_layout
import nimx/property_visitor
import nimx/numeric_text_field
import nimx/system_logger
import nimx/image_preview

import nimx/property_editors/propedit_registry

import variant

when defined(js):
    from dom import alert, window
elif not defined(android) and not defined(ios):
    import os_files/dialog

template toStr(v: SomeFloat, precision: uint): string = formatFloat(v, ffDecimal, precision)
template toStr(v: SomeInteger): string = $v

template fromStr(v: string, t: var SomeFloat) = t = v.parseFloat()
template fromStr(v: string, t: var SomeInteger) = t = type(t)(v.parseInt())

proc newScalarPropertyView[T](w: Window, setter: proc(s: T), getter: proc(): T): PropertyEditorView =
    result = PropertyEditorView.new(w, newRect(0, 0, 208, editorRowHeight))
    let tf = newNumericTextField(w, newRect(0, 0, 208, editorRowHeight))
    tf.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    tf.font = systemFontOfSize(w.gfxCtx.fontCtx, 14.0)
    when T is SomeFloat:
        tf.text = toStr(getter(), tf.precision)
    else:
        tf.text = toStr(getter())
    tf.onAction do():
        var v: T
        try:
            fromStr(tf.text, v)
            setter(v)

        except ValueError:
            discard
    result.addSubview(tf)

proc newTextPropertyView(w: Window, setter: proc(s: string), getter: proc(): string): PropertyEditorView =
    result = PropertyEditorView.new(w, newRect(0, 0, 208, editorRowHeight))
    let textField = newTextField(w, newRect(0, 0, 208, editorRowHeight))
    textField.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    textField.font = systemFontOfSize(w.gfxCtx.fontCtx, 14.0)
    textField.text = getter()
    textField.onAction do():
        setter(textField.text)

    result.addSubview(textField)

proc newVecPropertyView[T](w: Window, setter: proc(s: T), getter: proc(): T): PropertyEditorView =
    result = PropertyEditorView.new(w, newRect(0, 0, 208, editorRowHeight))
    const vecLen = high(T) + 1

    let horLayout = newHorizontalLayout(w, newRect(0, 0, 208, editorRowHeight))
    horLayout.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    result.addSubview(horLayout)

    proc complexSetter() =
        var val : TVector[vecLen, Coord]
        for i in 0 ..< horLayout.subviews.len:
            try:
                val[i] = TextField(horLayout.subviews[i]).text.parseFloat()
            except ValueError:
                return
        setter(val)

    let val = getter()
    for i in 0 ..< vecLen:
        let textField = newNumericTextField(w, zeroRect)
        textField.name = "#" & $i
        textField.font = systemFontOfSize(w.gfxCtx.fontCtx, 14.0)
        textField.text = toStr(val[i], textField.precision)
        textField.onAction complexSetter
        horLayout.addSubview(textField)

type ColorComponentTextField = ref object of NumericTextField
    onBecomeFirstResponder: proc()
    onResignFirstResponder: proc()

method viewDidBecomeFirstResponder*(t: ColorComponentTextField) =
    procCall t.NumericTextField.viewDidBecomeFirstResponder()
    if not t.onBecomeFirstResponder.isNil: t.onBecomeFirstResponder()

method viewShouldResignFirstResponder*(t: ColorComponentTextField, newFirstResponder: View): bool =
    result = procCall t.NumericTextField.viewShouldResignFirstResponder(newFirstResponder)
    if result and not t.onResignFirstResponder.isNil: t.onResignFirstResponder()

proc newColorPropertyView(w: Window, setter: proc(s: Color), getter: proc(): Color): PropertyEditorView =
    result = PropertyEditorView.new(w, newRect(0, 0, 208, editorRowHeight))
    const vecLen = 3 + 1

    var beginColorPicker: proc()
    var colorInColorPickerSelected: proc(pc: Color)

    let colorView = Button.new(w, newRect(0, 0, editorRowHeight, editorRowHeight))
    colorView.backgroundColor = getter()
    result.addSubview(colorView)
    colorView.hasBezel = false
    colorView.onAction beginColorPicker

    let horLayout = newHorizontalLayout(w, newRect(editorRowHeight, 0, result.bounds.width - editorRowHeight, editorRowHeight))
    horLayout.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    result.addSubview(horLayout)

    let colorPicker = newColorPickerView(w)
    proc complexSetter() =
        try:
            let c = newColor(
                TextField(horLayout.subviews[0]).text.parseFloat(),
                TextField(horLayout.subviews[1]).text.parseFloat(),
                TextField(horLayout.subviews[2]).text.parseFloat(),
                TextField(horLayout.subviews[3]).text.parseFloat(),
                )
            setter(c)
            colorView.backgroundColor = c

            if colorPicker.onColorSelected == colorInColorPickerSelected:
                colorPicker.color = c
        except ValueError:
            discard

    colorInColorPickerSelected = proc(pc: Color) =
        TextField(horLayout.subviews[0]).text = toStr(pc.r, 2)
        TextField(horLayout.subviews[1]).text = toStr(pc.g, 2)
        TextField(horLayout.subviews[2]).text = toStr(pc.b, 2)
        var c = pc
        c.a = try: TextField(horLayout.subviews[3]).text.parseFloat() except: 1.0
        setter(c)
        colorView.backgroundColor = c

    beginColorPicker = proc() =
        colorPicker.color = getter()
        colorPicker.onColorSelected = colorInColorPickerSelected
        colorPicker.popupAtPoint(colorView, newPoint(0, colorView.bounds.maxY))

    proc endColorPicker() =
        if colorPicker.onColorSelected == colorInColorPickerSelected:
            colorPicker.onColorSelected = nil
            colorPicker.removeFromSuperview()

    template toVector(c: Color): Vector4 = newVector4(c.r, c.g, c.b, c.a)

    for i in 0 ..< vecLen:
        let textField = ColorComponentTextField.new(w, zeroRect)
        textField.font = systemFontOfSize(w.gfxCtx.fontCtx, 14.0)
        textField.text = toStr(getter().toVector[i], textField.precision)
        textField.onAction complexSetter
        textField.onBecomeFirstResponder = beginColorPicker
        textField.onResignFirstResponder = endColorPicker
        textField.continuous = true
        horLayout.addSubview(textField)

proc newRectPropertyView(w: Window, setter: proc(s: Rect), getter: proc(): Rect): PropertyEditorView =
    newVecPropertyView(
        w,
        proc(v: Vector4) = setter(newRect(v.x, v.y, v.z, v.w)),
        proc(): Vector4 =
            let s = getter()
            result = newVector4(s.x, s.y, s.width, s.height)
            )

proc newSizePropertyView(w: Window, setter: proc(s: Size), getter: proc(): Size): PropertyEditorView =
    newVecPropertyView(
        w,
        proc(v: Vector2) = setter(newSize(v.x, v.y)),
        proc(): Vector2 =
            let s = getter()
            result = newVector2(s.width, s.height)
            )

proc newPointPropertyView(w: Window, setter: proc(s: Point), getter: proc(): Point): PropertyEditorView =
    newVecPropertyView(
        w,
        proc(v: Vector2) = setter(newPoint(v.x, v.y)),
        proc(): Vector2 =
            let s = getter()
            result = newVector2(s.x, s.y)
            )

when not defined(android) and not defined(ios):
    proc newImagePropertyView(w: Window, setter: proc(s: Image), getter: proc(): Image): PropertyEditorView =
        var loadedImage = getter()
        var pv: PropertyEditorView
        if not loadedImage.isNil:
            let previewSize = 48.0
            pv = PropertyEditorView.new(w, newRect(0, 0, 208, editorRowHeight + 6 + previewSize))

            let imgButton = newImageButton(pv, w, newPoint(0, editorRowHeight + 3), newSize(previewSize, previewSize), loadedImage)
            imgButton.onAction do():
                let imgPreview = newImagePreview(w, newRect(0, 0, 200, 200), loadedImage)
                imgPreview.popupAtPoint(pv, newPoint(-10, 0))

            let label = newLabel(w, newRect(previewSize + 5, editorRowHeight + 5 + editorRowHeight, 100, 15))
            label.text = "S: " & $int(loadedImage.size.width) & " x " & $int(loadedImage.size.height)
            label.textColor = newGrayColor(0.9)
            pv.addSubview(label)

            let removeButton = Button.new(w, newRect(previewSize + 5, editorRowHeight + 3, editorRowHeight, editorRowHeight))
            removeButton.title = "-"
            pv.addSubview(removeButton)
            removeButton.onAction do():
                setter(nil)
                if not pv.changeInspector.isNil:
                    pv.changeInspector()
        else:
            pv = PropertyEditorView.new(w, newRect(0, 0, 208, editorRowHeight))

        let b = Button.new(w, newRect(0, 0, 208, editorRowHeight))
        b.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
        b.title = "Open image..."
        b.onAction do():
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
                    except:
                        logi "Image could not be loaded: ", path
                    if not i.isNil:
                        setter(i)
                        if not pv.changeInspector.isNil:
                            pv.changeInspector()

        result = pv
        result.addSubview(b)

    registerPropertyEditor(newImagePropertyView)

proc newBoolPropertyView(w: Window, setter: proc(s: bool), getter: proc(): bool): PropertyEditorView =
    let pv = PropertyEditorView.new(w, newRect(0, 0, 208, editorRowHeight))
    let cb = newCheckbox(w, newRect(0, 0, editorRowHeight, editorRowHeight))
    cb.value = if getter(): 1 else: 0
    cb.onAction do():
        setter(cb.boolValue)
    result = pv
    result.addSubview(cb)

proc newEnumPropertyView(w: Window, setter: proc(s: EnumValue), getter: proc(): EnumValue): PropertyEditorView =
    let pv = PropertyEditorView.new(w, newRect(0, 0, 208, editorRowHeight))
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

    var enumChooser = newPopupButton(pv,
        w,
        newPoint(0.0, 0.0), newSize(208, editorRowHeight),
        items, startVal)

    enumChooser.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}

    enumChooser.onAction do():
        val.curValue = val.possibleValues[enumChooser.selectedItem()]
        setter(val)
        if not pv.changeInspector.isNil:
            pv.changeInspector()

    result = pv

proc newScalarSeqPropertyView[T](w: Window, setter: proc(s: seq[T]), getter: proc(): seq[T]): PropertyEditorView =
    var val = getter()
    var height = val.len() * 26 + 26
    let pv = PropertyEditorView.new(w, newRect(0, 0, 208, height.Coord))

    proc onValChange() =
        setter(val)

    proc onSeqChange() =
        onValChange()
        if not pv.changeInspector.isNil:
            pv.changeInspector()

    var y = 0.Coord
    for i in 0 ..< val.len:
        closureScope:
            let index = i
            let tf = newNumericTextField(w, newRect(0.Coord, y, 150, editorRowHeight))
            tf.font = systemFontOfSize(w.gfxCtx.fontCtx, 14.0)
            pv.addSubview(tf)
            tf.text = toStr(val[i], tf.precision)
            tf.onAction do():
                if index < val.len:
                    fromStr(tf.text, val[index])
                    onValChange()

            let removeButton = Button.new(w, newRect(153, y, editorRowHeight, editorRowHeight))
            removeButton.title = "-"
            pv.addSubview(removeButton)
            removeButton.onAction do():
                val.delete(index)
                onSeqChange()

            y += 18

    let addButton = Button.new(w, newRect(153, y, editorRowHeight, editorRowHeight))
    addButton.title = "+"
    pv.addSubview(addButton)
    addButton.onAction do():
        val.add(0.0)
        onSeqChange()

    result = pv

# proc newSeqPropertyView[I: static[int], T](setter: proc(s: seq[TVector[I, T]]), getter: proc(): seq[TVector[I, T]]): PropertyEditorView =
proc newSeqPropertyView[T](w: Window, setter: proc(s: seq[T]), getter: proc(): seq[T]): PropertyEditorView =
    var val = getter()
    var height = val.len() * 26 + 26
    let pv = PropertyEditorView.new(w, newRect(0, 0, 208, height.Coord))
    const vecLen = high(T) + 1

    proc onValChange() =
        setter(val)

    proc onSeqChange() =
        onValChange()
        if not pv.changeInspector.isNil:
            pv.changeInspector()

    var x = 0.Coord
    var y = 0.Coord
    for i in 0 ..< val.len:
        closureScope:
            let index = i
            var vecVal = val[i]

            x = 0.Coord
            for j in 0 ..< vecLen:
                closureScope:
                    let jIndex = j
                    let tf = newNumericTextField(w, newRect(x, y, 35, editorRowHeight))
                    tf.font = systemFontOfSize(w.gfxCtx.fontCtx, 14.0)
                    x += 37
                    pv.addSubview(tf)
                    tf.text = toStr(vecVal[j], tf.precision)
                    tf.onAction do():
                        if index < val.len:
                            val[index][jIndex] = tf.text.parseFloat()
                            onValChange()

            let removeButton = Button.new(w, newRect(x, y, editorRowHeight, editorRowHeight))
            removeButton.title = "-"
            pv.addSubview(removeButton)
            removeButton.onAction do():
                val.delete(index)
                onSeqChange()

            y += editorRowHeight + 2

    let addButton = Button.new(w, newRect(x, y, editorRowHeight, editorRowHeight))
    addButton.title = "+"
    pv.addSubview(addButton)
    addButton.onAction do():
        var newVal : TVector[vecLen, Coord]
        val.add(newVal)
        onSeqChange()

    result = pv

proc newFontPropertyView(w: Window, setter: proc(s: Font), getter: proc(): Font): PropertyEditorView =
    result = PropertyEditorView.new(w, newRect(0, 0, 208, editorRowHeight))
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

    var enumChooser = newPopupButton(result, w,
        newPoint(0.0, 0.0), newSize(208, editorRowHeight),
        items, startVal)

    enumChooser.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}

    enumChooser.onAction do():
        let val = newFontWithFace(w.gfxCtx.fontCtx, enumChooser.selectedItem(), fontSize)
        setter(val)


registerPropertyEditor(newTextPropertyView)
registerPropertyEditor(newScalarPropertyView[Coord])
registerPropertyEditor(newScalarPropertyView[float])
registerPropertyEditor(newScalarPropertyView[int])
registerPropertyEditor(newScalarPropertyView[int16])
registerPropertyEditor(newVecPropertyView[Vector2])
registerPropertyEditor(newVecPropertyView[Vector3])
registerPropertyEditor(newVecPropertyView[Vector4])
registerPropertyEditor(newColorPropertyView)
registerPropertyEditor(newSizePropertyView)
registerPropertyEditor(newRectPropertyView)
registerPropertyEditor(newPointPropertyView)
registerPropertyEditor(newBoolPropertyView)
registerPropertyEditor(newEnumPropertyView)
registerPropertyEditor(newScalarSeqPropertyView[float])
registerPropertyEditor(newSeqPropertyView[TVector[4, Coord]])
registerPropertyEditor(newSeqPropertyView[TVector[5, Coord]])
registerPropertyEditor(newFontPropertyView)


template initPropertyEditor*(v: View, eo: untyped, propName: string, property: untyped)=
    var o = newVariant(eo)
    var visitor : PropertyVisitor
    visitor.requireName = true
    visitor.requireSetter = true
    visitor.requireGetter = true
    visitor.flags = { pfEditable }
    visitor.commit = proc() =
        v.addSubview(propertyEditorForProperty(v.window, o, visitor.name, visitor.setterAndGetter))

    visitor.visitProperty(propName, property)
