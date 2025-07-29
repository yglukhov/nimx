import sugar
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

var testLayoutRegistry {.threadvar.}: seq[tuple[name: string, createProc, testProc: proc(wnd: Window) {.gcsafe.}]]

template reg(name: string, body: untyped) =
  block:
    var createProc: proc(w: Window) {.gcsafe.}
    var testProc: proc(w: Window) {.gcsafe.}
    template make(createBody: untyped) =
      createProc = proc(w: Window) {.gcsafe.} =
        let wnd {.inject.} = w
        createBody
    template test(testBody: untyped) {.used.}=
      testProc = proc(w: Window) {.gcsafe.} =
        let wnd {.inject.} = w
        testBody
    body
    testLayoutRegistry.add((name, createProc, testProc))

reg "Hello world":
  make:
    wnd.makeLayout:
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

reg "Some layout":
  make:
    const margin = 20

    wnd.makeLayout:
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

reg "Some layout 3":
  make:
    wnd.makeLayout:
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

reg "Some layout 4":
  make:
    wnd.makeLayout:
      - SplitView as sv:
        vertical: true # Comment this line to make me horizontal
        backgroundColor: blue
        frame == super

        - TestView:
          backgroundColor: red
          size >= [200, 200]

        - View:
          backgroundColor: green
          size >= [200, 200]

        - View:
          backgroundColor: yellow
          size >= [200, 200]

reg "Some layout 5":
  make:
    wnd.makeLayout:
      - View:
        backgroundColor: blue
        frame == inset(super, 10, 100, 10, 300)

reg "SplitView":
  make:
    wnd.makeLayout:
      - SplitView:
        frame == inset(super, 10)

        - ScrollView:
          backgroundColor: blue
          size >= [200, 500]
          - TestView:
            backgroundColor: red
            size == [200, 900]

        - TestView:
          backgroundColor: yellow
          width >= 100

reg "Table in SplitView":
  make:
    var tableValues = newSeq[string]()
    for i in 0 .. 50:
      tableValues.add("Item " & $i)

    wnd.makeLayout:
      - SplitView:
        frame == inset(super, 10)

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
                  frame == super
                  width == 200

            configureCell do(c: TableViewCell):
              Label(c.subviews[0]).text = tableValues[c.row]

        - TestView:
          backgroundColor: yellow

    tv.reloadData()

reg "Autoresizing Frame":
  make:
    wnd.makeLayout:
      - TestView:
        frame == autoresizingFrame(10, 100, NaN, 10, 100, NaN)
        backgroundColor: red

      - TestView:
        frame == autoresizingFrame(110, NaN, 110, 10, 100, NaN)
        backgroundColor: blue

      - TestView:
        frame == autoresizingFrame(NaN, 100, 10, 10, 100, NaN)
        backgroundColor: yellow

      - TestView:
        frame == autoresizingFrame(10, 100, NaN, 110, NaN, 110)
        backgroundColor: green

      - TestView:
        frame == autoresizingFrame(110, NaN, 110, 110, NaN, 110)
        backgroundColor: red

      - TestView:
        frame == autoresizingFrame(NaN, 100, 10, 110, NaN, 110)
        backgroundColor: blue

      - TestView:
        frame == autoresizingFrame(10, 100, NaN, NaN, 100, 10)
        backgroundColor: yellow

      - TestView:
        frame == autoresizingFrame(110, NaN, 110, NaN, 100, 10)
        backgroundColor: blue

      - TestView:
        frame == autoresizingFrame(NaN, 100, 10, NaN, 100, 10)
        backgroundColor: green

method init(v: LayoutSampleView, r: Rect) =
  procCall v.View.init(r)
  var by = 5'f32
  for ii in testLayoutRegistry:
    let i = ii
    capture i:
      v.makeLayout:
        - Button:
          title: i.name
          frame == autoresizingFrame(10, 150, NaN, by, 25, NaN)
          onAction:
            let wnd = newWindow(newRect(80, 80, 800, 600))
            wnd.title = i.name
            i.createProc(wnd)

    by += 30

registerSample(LayoutSampleView, "Layout")
