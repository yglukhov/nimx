import sample_registry
import nimx / [ view, window, button, text_field, layout, scroll_view, table_view,
                split_view, context ]

type LayoutSampleView = ref object of View


type TestView = ref object of View
method draw*(v: TestView, r: Rect) =
    procCall v.View.draw(r)
    let c = currentContext()
    c.strokeWidth = 2
    c.strokeColor = blackColor()
    let b = v.bounds
    c.drawLine(b.origin, b.maxCorner)
    c.drawLine(newPoint(b.maxX, b.minY), newPoint(b.minX, b.maxY))

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


proc createLayout3(w: Window) =
    w.makeLayout:
        - View:
            backgroundColor: red
            x == 5
            y == 5
            width == super.width / 2
            height == super.height / 2

            - View:
                backgroundColor: green
                x == super.x + 5
                y == super.x + 5
                width == 200
                height == 200

                - View:
                    backgroundColor: blue
                    x == super.x + 5
                    y == super.y + 5
                    width == 100
                    height == 100

        - Button:
            title: "btn1"
            onAction:
                echo "hi btn1"
            width == 50
            height == 25
            # x == 10.0
            # y == 10.0
            # right == 10.0
            # height == super.height - 20
            centerX == super.centerX
            centerY == super.centerY

proc createLayout4(w: Window) =
    w.makeLayout:
        - SplitView as sv:
            vertical: true # Comment this line to make me horizontal
            backgroundColor: blue
            top == super
            bottom == super
            leading == super
            trailing == super

            - TestView:
                backgroundColor: red
                width >= 200
                height >= 200

            - View:
                backgroundColor: green
                width >= 200
                height >= 200

            - View:
                backgroundColor: yellow
                width >= 200
                height >= 200


proc createLayout5(w: Window) =
    w.makeLayout:
        - View:
            backgroundColor: blue
            leading == super + 10
            trailing == super - 10
            top == 100
            bottom == 300

proc createLayout6(w: Window) =
    w.makeLayout:
        - SplitView:
            leading == super + 10
            trailing == super - 10
            top == super + 10
            bottom == super - 10

            - ScrollView:
                backgroundColor: blue
                width >= 200
                height >= 500
                - TestView:
                    backgroundColor: red
                    width == 200
                    height == 900

            - TestView:
                backgroundColor: yellow
                width >= 100

proc createLayout7(w: Window) =
    var tableValues = newSeq[string]()
    for i in 0 .. 50:
        tableValues.add("Item " & $i)

    w.makeLayout:
        - SplitView:
            leading == super + 10
            trailing == super - 10
            top == super + 10
            bottom == super - 10

            - ScrollView:
                backgroundColor: blue
                width >= 200
                - TableView as tv:
                    width == 200
                    backgroundColor: red
                    numberOfRows do() -> int:
                        tableValues.len

                    createCell do() -> TableViewCell:
                        result = TableViewCell.new(zeroRect)
                        result.makeLayout:
                            top == super
                            bottom == super

                            - Label:
                                leading == super
                                trailing == super
                                top == super
                                bottom == super
                                width == 200

                    configureCell do(c: TableViewCell):
                        Label(c.subviews[0]).text = tableValues[c.row]

            - TestView:
                backgroundColor: yellow

    tv.reloadData()


method init(v: LayoutSampleView, r: Rect) =
    procCall v.View.init(r)
    var by = 5'f32
    template reg(name: string, t: proc(w: Window)) =
        let b = Button.new(newRect(5, by, 150, 25))
        b.title = name
        by += 30
        b.onAction do():
            let wnd = newWindow(newRect(80, 80, 800, 600))
            wnd.title = name
            t(wnd)
        v.addSubview(b)

    reg "Hello world", createLayout1
    reg "Some layout", createLayout2
    reg "Some layout 3", createLayout3
    reg "Some layout 4", createLayout4
    reg "Some layout 5", createLayout5
    reg "SplitView", createLayout6
    reg "Table in SplitView", createLayout7

registerSample(LayoutSampleView, "Layout")
