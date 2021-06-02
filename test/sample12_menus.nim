import sample_registry
import nimx / [ view, menu, button, text_field ]

type MenuSampleView = ref object of View

proc leftOf(v: View, width: Coord): Rect =
    let f = v.frame
    result.origin.x = f.maxX + 5
    result.origin.y = f.y
    result.size.height = f.height
    result.size.width = width

method init(v: MenuSampleView, w: Window, r: Rect) =
    procCall v.View.init(w, r)
    let b = Button.new(w, newRect(5, 5, 100, 25))
    b.title = "Menu"

    let textField = TextField.new(w, b.leftOf(120))
    textField.text = "Menu: none"

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
    v.addSubview(b)
    v.addSubview(textField)

registerSample(MenuSampleView, "Menus")
