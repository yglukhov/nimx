import sample_registry
import nimx / [ view, menu, button, text_field, layout ]

type MenuSampleView = ref object of View

proc leftOf(v: View, width: Coord): Rect =
    let f = v.frame
    result.origin.x = f.maxX + 5
    result.origin.y = f.y
    result.size.height = f.height
    result.size.width = width

method init(v: MenuSampleView, r: Rect) =
    procCall v.View.init(r)
    v.makeLayout:
        - Button as b:
            origin == super + 5
            width == 100
            height == 25
            title: "Menu"

        - TextField as textField:
            leading == prev.trailing + 5
            y == prev
            height == prev
            width == 120
            text: "Menu: none"
            
    let m = makeMenu("File"):
            - "Open":
                textField.text = "Menu: Open"
                echo "Open"
            - "Save":
                textField.text = "Menu: Save"
            - "-"
            + "Bye":
                - "Sub1"
                - "-"
                - "Sub2":
                    textField.text = "Menu: Sub2"

    b.onAction do():
        m.popupAtPoint(b, newPoint(0, 25))

registerSample(MenuSampleView, "Menus")
