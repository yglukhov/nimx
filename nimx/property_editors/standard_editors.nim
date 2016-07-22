import strutils
import tables
import algorithm

import nimx.view
import nimx.text_field
import nimx.matrixes
import nimx.image
import nimx.button
import nimx.color_picker
import nimx.context
import nimx.portable_gl
import nimx.popup_button
import nimx.font
import nimx.linear_layout
import nimx.property_visitor
import nimx.numeric_text_field

import nimx.property_editors.propedit_registry

import variant

when defined(js):
    from dom import alert
elif not defined(android) and not defined(ios) and not defined(emscripten):
    import native_dialogs

template toStr(v: SomeReal, precision: uint): string = formatFloat(v, ffDecimal, precision)
template toStr(v: SomeInteger): string = $v

template fromStr(v: string, t: var SomeReal) = t = v.parseFloat()
template fromStr(v: string, t: var SomeInteger) = t = v.parseInt()

proc newScalarPropertyView[T](setter: proc(s: T), getter: proc(): T): PropertyEditorView =
    result = PropertyEditorView.new(newRect(0, 0, 208, editorRowHeight))
    let tf = newNumericTextField(newRect(0, 0, 208, editorRowHeight))
    tf.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    tf.font = editorFont()
    when T is SomeReal:
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

proc newTextPropertyView(setter: proc(s: string), getter: proc(): string): PropertyEditorView =
    result = PropertyEditorView.new(newRect(0, 0, 208, editorRowHeight))
    let textField = newTextField(newRect(0, 0, 208, editorRowHeight))
    textField.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    textField.font = editorFont()
    textField.text = getter()
    textField.onAction do():
        setter(textField.text)

    result.addSubview(textField)

proc newVecPropertyView[T](setter: proc(s: T), getter: proc(): T): PropertyEditorView =
    result = PropertyEditorView.new(newRect(0, 0, 208, editorRowHeight))
    const vecLen = high(T) + 1

    let horLayout = newHorizontalLayout(newRect(0, 0, 208, editorRowHeight))
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
        let textField = newNumericTextField(zeroRect)
        textField.font = editorFont()
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

proc newColorPropertyView(setter: proc(s: Color), getter: proc(): Color): PropertyEditorView =
    result = PropertyEditorView.new(newRect(0, 0, 208, editorRowHeight))
    const vecLen = 3 + 1

    var beginColorPicker: proc()
    var colorInColorPickerSelected: proc(pc: Color)

    let colorView = Button.new(newRect(0, 0, editorRowHeight, editorRowHeight))
    colorView.backgroundColor = getter()
    result.addSubview(colorView)
    colorView.hasBezel = false
    colorView.onAction beginColorPicker

    let horLayout = newHorizontalLayout(newRect(editorRowHeight, 0, result.bounds.width - editorRowHeight, editorRowHeight))
    horLayout.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    result.addSubview(horLayout)

    let colorPicker = sharedColorPicker()
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
        let textField = ColorComponentTextField.new(zeroRect)
        textField.font = editorFont()
        textField.text = toStr(getter().toVector[i], textField.precision)
        textField.onAction complexSetter
        textField.onBecomeFirstResponder = beginColorPicker
        textField.onResignFirstResponder = endColorPicker
        textField.continuous = true
        horLayout.addSubview(textField)

proc newSizePropertyView(setter: proc(s: Size), getter: proc(): Size): PropertyEditorView =
    newVecPropertyView(
        proc(v: Vector2) = setter(newSize(v.x, v.y)),
        proc(): Vector2 =
            let s = getter()
            result = newVector2(s.width, s.height)
            )

proc newPointPropertyView(setter: proc(s: Point), getter: proc(): Point): PropertyEditorView =
    newVecPropertyView(
        proc(v: Vector2) = setter(newPoint(v.x, v.y)),
        proc(): Vector2 =
            let s = getter()
            result = newVector2(s.x, s.y)
            )

when not defined(android) and not defined(ios):
    proc newImagePropertyView(setter: proc(s: Image), getter: proc(): Image): PropertyEditorView =
        let pv = PropertyEditorView.new(newRect(0, 0, 208, editorRowHeight))
        let b = Button.new(newRect(0, 0, 208, editorRowHeight))
        b.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
        b.title = "Open image..."
        b.onAction do():
            when defined(js):
                alert("Files can be opened only in native editor version")
            elif defined(emscripten):
                discard
            else:
                let path = callDialogFileOpen("Select Image")
                if not path.isNil:
                    setter(imageWithContentsOfFile(path))
                    if not pv.onChange.isNil:
                        pv.onChange()

        result = pv
        result.addSubview(b)

    registerPropertyEditor(newImagePropertyView)

proc newBoolPropertyView(setter: proc(s: bool), getter: proc(): bool): PropertyEditorView =
    let pv = PropertyEditorView.new(newRect(0, 0, 208, editorRowHeight))
    let cb = newCheckbox(newRect(0, 0, editorRowHeight, editorRowHeight))
    cb.value = if getter(): 1 else: 0
    cb.onAction do():
        setter(cb.boolValue)

        if not pv.onChange.isNil:
            pv.onChange()

    result = pv
    result.addSubview(cb)

proc newEnumPropertyView(setter: proc(s: EnumValue), getter: proc(): EnumValue): PropertyEditorView =
    let pv = PropertyEditorView.new(newRect(0, 0, 208, editorRowHeight))
    var val = getter()
    var items = newSeq[string]()
    for k, v in val.possibleValues:
        items.add(k)

    sort(items, system.cmp)
    var enumChooser = newPopupButton(pv,
        newPoint(0.0, 0.0), newSize(208, editorRowHeight),
        items, val.curValue)

    enumChooser.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}

    enumChooser.onAction do():
        val.curValue = val.possibleValues[enumChooser.selectedItem()]
        setter(val)
        if not pv.changeInspector.isNil:
            pv.changeInspector()

    result = pv

template closureScope*(body: untyped): stmt = (proc() = body)()
proc newScalarSeqPropertyView[T](setter: proc(s: seq[T]), getter: proc(): seq[T]): PropertyEditorView =
    var val = getter()
    var height = val.len() * 26 + 26
    let pv = PropertyEditorView.new(newRect(0, 0, 208, height.Coord))

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
            let tf = newNumericTextField(newRect(0.Coord, y, 150, editorRowHeight))
            tf.font = editorFont()
            pv.addSubview(tf)
            tf.text = toStr(val[i], tf.precision)
            tf.onAction do():
                if index < val.len:
                    fromStr(tf.text, val[index])
                    onValChange()

            let removeButton = Button.new(newRect(153, y, editorRowHeight, editorRowHeight))
            removeButton.title = "-"
            pv.addSubview(removeButton)
            removeButton.onAction do():
                val.delete(index)
                onSeqChange()

            y += 18

    let addButton = Button.new(newRect(153, y, editorRowHeight, editorRowHeight))
    addButton.title = "+"
    pv.addSubview(addButton)
    addButton.onAction do():
        val.add(0.0)
        onSeqChange()

    result = pv

# proc newSeqPropertyView[I: static[int], T](setter: proc(s: seq[TVector[I, T]]), getter: proc(): seq[TVector[I, T]]): PropertyEditorView =
proc newSeqPropertyView[T](setter: proc(s: seq[T]), getter: proc(): seq[T]): PropertyEditorView =
    var val = getter()
    var height = val.len() * 26 + 26
    let pv = PropertyEditorView.new(newRect(0, 0, 208, height.Coord))
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
                    let tf = newNumericTextField(newRect(x, y, 35, editorRowHeight))
                    tf.font = editorFont()
                    x += 37
                    pv.addSubview(tf)
                    tf.text = toStr(vecVal[j], tf.precision)
                    tf.onAction do():
                        if index < val.len:
                            val[index][jIndex] = tf.text.parseFloat()
                            onValChange()

            let removeButton = Button.new(newRect(x, y, editorRowHeight, editorRowHeight))
            removeButton.title = "-"
            pv.addSubview(removeButton)
            removeButton.onAction do():
                val.delete(index)
                onSeqChange()

            y += editorRowHeight + 2

    let addButton = Button.new(newRect(x, y, editorRowHeight, editorRowHeight))
    addButton.title = "+"
    pv.addSubview(addButton)
    addButton.onAction do():
        var newVal : TVector[vecLen, Coord]
        val.add(newVal)
        onSeqChange()

    result = pv

registerPropertyEditor(newTextPropertyView)
registerPropertyEditor(newScalarPropertyView[Coord])
registerPropertyEditor(newScalarPropertyView[float])
registerPropertyEditor(newScalarPropertyView[int])
registerPropertyEditor(newVecPropertyView[Vector2])
registerPropertyEditor(newVecPropertyView[Vector3])
registerPropertyEditor(newVecPropertyView[Vector4])
registerPropertyEditor(newColorPropertyView)
registerPropertyEditor(newSizePropertyView)
registerPropertyEditor(newPointPropertyView)
registerPropertyEditor(newBoolPropertyView)
registerPropertyEditor(newEnumPropertyView)
registerPropertyEditor(newScalarSeqPropertyView[float])
registerPropertyEditor(newSeqPropertyView[TVector[4, Coord]])
registerPropertyEditor(newSeqPropertyView[TVector[5, Coord]])
