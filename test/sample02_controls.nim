import sample_registry

import nimx.view
import nimx.segmented_control
import nimx.button
import nimx.text_field

type ControlsSampleView = ref object of View

method init(v: ControlsSampleView, r: Rect) =
    procCall v.View.init(r)

    let label = newLabel(newRect(10, 10, 100, 20))
    let textField = newTextField(newRect(120, 10, v.bounds.width - 130, 20))
    textField.autoresizingMask = { afFlexibleWidth, afFlexibleMaxY }
    label.text = "Text field:"
    v.addSubview(label)
    v.addSubview(textField)

    let button = newButton(newRect(10, 40, 100, 20))
    button.title = "Button"
    button.onAction do():
        if textField.text.isNil: textField.text = ""
        textField.text &= "Click! "
        textField.setNeedsDisplay()
    v.addSubview(button)

    let sc = SegmentedControl.new(newRect(120, 40, v.bounds.width - 130, 20))
    sc.segments = @["This", "is", "a", "segmented", "control"]
    sc.autoresizingMask = { afFlexibleWidth, afFlexibleMaxY }
    sc.onAction do():
        if textField.text.isNil: textField.text = ""
        textField.text &= "Seg " & $sc.selectedSegment & "! "
        textField.setNeedsDisplay()

    v.addSubview(sc)

    let checkbox = newCheckbox(newRect(10, 70, 50, 16))
    checkbox.title = "Checkbox"
    v.addSubview(checkbox)

    let radiobox = newRadiobox(newRect(10, 90, 50, 16))
    radiobox.title = "Radiobox"
    v.addSubview(radiobox)

registerSample "Controls", ControlsSampleView.new(newRect(0, 0, 100, 100))
