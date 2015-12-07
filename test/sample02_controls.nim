import sample_registry

import nimx.view
import nimx.segmented_control
import nimx.button
import nimx.text_field
import nimx.slider
import nimx.popup_button
import nimx.progress_indicator

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

    let progress = ProgressIndicator.new(newRect(120, 130, v.bounds.width - 130, 16))
    progress.autoresizingMask = { afFlexibleWidth, afFlexibleMaxY }
    v.addSubview(progress)

    let slider = Slider.new(newRect(120, 70, v.bounds.width - 130, 16))
    slider.autoresizingMask = { afFlexibleWidth, afFlexibleMaxY }
    slider.onAction do():
        textField.text = "Slider value: " & $slider.value & " "
        progress.value = slider.value
        textField.setNeedsDisplay()
    v.addSubview(slider)

    let vertSlider = Slider.new(newRect(v.bounds.width - 26, 150, 16, v.bounds.height - 160))
    vertSlider.autoresizingMask = { afFlexibleMinX, afFlexibleHeight }
    v.addSubview(vertSlider)

    let radiobox = newRadiobox(newRect(10, 90, 50, 16))
    radiobox.title = "Radiobox"
    v.addSubview(radiobox)

    let indeterminateCheckbox = newCheckbox(newRect(10, 130, 100, 16))
    indeterminateCheckbox.title = "Indeterminate"
    indeterminateCheckbox.onAction do():
        progress.indeterminate = indeterminateCheckbox.boolValue
    v.addSubview(indeterminateCheckbox)

    let pb = PopupButton.new(newRect(120, 90, 120, 20))
    pb.items = @["Popup button", "Item 1", "Item 2"]
    v.addSubview(pb)

    let tfLabel = newLabel(newRect(330, 150, 150, 20))
    tfLabel.text = "<-- Enter some text"
    let tf1 = newTextField(newRect(10, 150, 150, 20))
    let tf2 = newTextField(newRect(170, 150, 150, 20))
    tf1.onAction do():
        tfLabel.text = "Left textfield: " & (if tf1.text.isNil: "nil" else: tf1.text)
    tf2.onAction do():
        tfLabel.text = "Right textfield: " & (if tf2.text.isNil: "nil" else: tf2.text)

    v.addSubview(tfLabel)
    v.addSubview(tf1)
    v.addSubview(tf2)

registerSample "Controls", ControlsSampleView.new(newRect(0, 0, 100, 100))
