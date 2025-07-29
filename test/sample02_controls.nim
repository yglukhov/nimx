import sample_registry

import nimx / [ view, segmented_control, color_picker, button, image, image_view,
                text_field, slider, popup_button, progress_indicator, layout ]
import nimx/assets/asset_manager

type ControlsSampleView = ref object of View

method init(v: ControlsSampleView, r: Rect) =
    procCall v.View.init(r)
    let margin = 10.Coord
    v.makeLayout:
        - Label:
            leading == super + margin
            y == super + margin
            width == 100
            height == 20
            text: "Text field: "
        - TextField as textField:
            leading == prev.trailing + margin
            trailing == super - margin
            y == prev
            height == prev

        - Button:
            leading == super + margin
            y == super + 40
            width == 100
            height == 22
            title: "Button"
            onAction do():
                textField.text = "Click! "

        - SegmentedControl as sc:
            leading == prev.trailing + margin
            trailing == super - margin
            y == prev
            height == prev
            segments: @["This", "is", "a", "segmented", "control"]
            onAction do():
                textField.text = "Seg " & $sc.selectedSegment & "! "

        - Checkbox as cb:
            title: "Checkbox"
            leading == super + margin
            y == super + 70
            height == 16
            width == 110

        - Slider as slider:
            leading == prev.trailing + margin
            trailing == super - margin
            y == prev
            height == prev
            onAction do():
                textField.text = "Slider value: " & $slider.value & " "
                progress.value = slider.value

        - ProgressIndicator as progress:
            leading == prev
            width == prev
            y == super + 130
            height == prev

        - Slider:
            trailing == super - margin
            width == 16
            y == super + 150
            bottom == super - margin

        - Radiobox as rb:
            leading == super + margin
            y == cb.layout.vars.bottom + margin
            size == cb.layout.vars.size
            title: "Radiobox"

        - PopupButton:
            leading == prev.trailing + margin
            y == prev
            width == 140
            height == 20
            items: @["Popup button", "Item 1", "Item 2"]

        - Checkbox as indeterminateCheckbox:
            leading == super + margin
            width == 110
            y == progress.layout.vars.y
            height == 16
            title: "Indeterminate"
            onAction do():
                progress.indeterminate = indeterminateCheckbox.boolValue

        - TextField as tf1:
            leading == super + margin
            y == super + 150
            height == 20
            onAction do():
                tfLabel.text = "Left: " & tf1.text

        - TextField as tf2:
            leading == prev.trailing + margin
            width == prev
            y == prev
            height == prev
            onAction do():
                tfLabel.text = "Right: " & tf2.text

        - Label as tfLabel:
            leading == prev.trailing + margin
            trailing == super - margin
            y == prev
            height == prev
            width == prev
            text: "<-- Enter some text"

        - ColorPickerView as cpv:
            leading == super + margin
            y == super + 200
            width == 400
            height == 170
            backgroundColor: newGrayColor(0.5)
            onAction:
                textField.text = $cpv.color

    sharedAssetManager().getAssetAtPath("cat.jpg") do(i: Image, err: string):
        v.makeLayout:
            - Button:
                leading == super + 280
                y == super + 90
                width == 32
                height == 32
                image: i

    sharedAssetManager().getAssetAtPath("tile.png") do(i: Image, err: string):
        v.makeLayout:
            - ImageView as imageView:
                leading == super
                y == super + 400
                width == 300
                bottom == super
                image: i
                backgroundColor: newGrayColor(0.9)
            - PopupButton as popupFillRule:
                leading == prev.trailing + 20
                y == prev
                width == 100
                height == 20
                items: ["NoFill", "Stretch", "Tile", "FitWidth", "FitHeight"]
                onAction:
                    imageView.fillRule = popupFillRule.selectedIndex().ImageFillRule

registerSample(ControlsSampleView, "Controls")
