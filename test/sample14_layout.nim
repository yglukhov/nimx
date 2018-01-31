import sample_registry
import nimx / [ view, window, button, text_field, layout ]

type LayoutSampleView = ref object of View

let red = newColor(1, 0, 0)
let green = newColor(0, 1, 0)
let blue = newColor(0, 0, 1)
let yellow = newColor(1, 1, 0)

proc createLayout1(w: Window) =
    w.makeLayout:
        - Label:
            text: "Hello, world!"
            y == 10.0
            height == 25.0
        - newButton(zeroRect) as mybu:
            title: "btn1"
            onAction do():
                echo "hi btn1"
            x == 10.0
            y == super.height - self.height - 10.0
            y >= prev.y + prev.height
            width >= 150
            height == 25
        - Button:
            title: "btn2"
            onAction:
                echo "hi btn2"
            x == super.width - self.width - 10.0
            x == prev.x + prev.width + 10.0
            y == prev.y
            width == prev.width
            height == prev.height

proc createLayout2(w: Window) =
    const margin = 20

    w.makeLayout:
        title: "Some layout"

        - View as myView:
            backgroundColor: red
            leading == super + margin
            top == super + margin
            bottom == super - margin

        - View:
            backgroundColor: green
            leading == prev.trailing
            trailing == super - margin
            top == prev
            size == prev

            - View:
                backgroundColor: blue
                leading == super + 10
                width == super / 2
                height == 50
                centerY == super

    myView.makeLayout:
        - View:
            backgroundColor: blue
            center == super
            width == super - 50
            height == 300 @ WEAK
            height <= super - 20
            height >= 20

method init(v: LayoutSampleView, r: Rect) =
    procCall v.View.init(r)
    var by = 5'f32
    template reg(name: string, t: proc(w: Window)) =
        let b = Button.new(newRect(5, by, 100, 25))
        b.title = name
        by += 30
        b.onAction do():
            let wnd = newWindow(newRect(80, 80, 800, 600))
            t(wnd)
        v.addSubview(b)

    reg "Hello world", createLayout1
    reg "Some layout", createLayout2

registerSample(LayoutSampleView, "Layout")
