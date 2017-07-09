import macros
import sample_registry

import nimx.view
import nimx.menu
import nimx.button

type MenuSampleView = ref object of View

method init(v: MenuSampleView, r: Rect) =
    procCall v.View.init(r)
    let b = Button.new(newRect(5, 5, 100, 25))
    b.title = "Menu"

    let m = makeMenu("File"):
            - "Open":
                echo "Open"
            - "Save":
                echo "Save"
            - "-"
            + "Bye":
                - "Sub1"
                - "Sub2"

    b.onAction do():
        m.popupAtPoint(b, newPoint(0, 25))
    v.addSubview(b)

registerSample(MenuSampleView, "Menus")
