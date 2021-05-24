Views
=====

**Views** within a window are used to layout controls or other views.

Note: a Panel view is a collapsable view.

Collection View
---------------

A [**collection** view](../nimx/collection_view.nim) will layout a collection (sequence) of items in a direction of either left-to-right or top-down, 
where items is a pre-defined size on the screen.

Each item is wrapped in a subview.
 
[See Test 7 code](../test/sample07_collections.nim)

Expanding View
--------------

An [**expanding** view](../nimx/expanding_view.nim) has a button that can be clicked to expand the view to display (or hide) the full content of the view.

A simple example:
```
import nimx / [ expanding_view, window, text_field ]

runApplication:
  let w = newWindow(newRect(50, 50, 500, 120))
  let ev1 = newExpandingView(newRect(0, 0, 500, 120), hasOffset = true)
  ev1.title = "My Exanding View"
  ev1.titleBarColor = newColor(0.1, 0.1, 0.6)
  ev1.expand()
  ev1.backgroundColor = newColor(0.95, 0.95, 0.95)
  ev1.contentView.backgroundColor = newColor(0.88, 0.88, 0.95)
  ev1.addContent(newLabel(nil, newPoint(0,0), newSize(150,26), "This is a Label"))
  let tf1 = newTextField(nil, newPoint(0,0), newSize(200,26), "This is a TextField")
  tf1.multiline = false
  ev1.addContent(tf1)
  w.addSubView(ev1)
```

[Also see Test 11 code](../test/sample11_expanded_views.nim)

Form View
---------

A **form** view lays out a specified number of label/Text_Field pairs.  The labels and values of the Text Fields can then be set with the `setValue()` 
or retrieved with the `inputValue()` procs.

Currently, to have different input types other than a Text Field would require overloading the [FormView definition](../nimx/form_view.nim).


Horizontal List View
--------------------

A scrollable [horizontal list](../nimx/horizontal_list_view.nim) of views


Image View
----------

[Image view](../nimx/image_view.nim) is a view for drawing static images.

Filling rules:
 - **NoFill** is drawn from the top-left corner with its size
 - **Stretch** is stretched to the view size
 - **Tile** all of the view
 - **FitWidth** to the view's width
 - **FitHeight** to the view's height
 - **NinePartImage**

Inspector View
--------------

A vertical layout [view](../nimx/inspector_view.nim) for inspecting object properties.

Outline View
------------

An [**Outline** view](../nimx/outline_view.nim) allows dragging of child elements to different levels of a hierarchical list.

Panel View
----------

A collapseable [view](../nimx/panel_view.nim) that allows the showing/hiding of its content.

The [inspector Panel](../nimx/inspector_panel.nim) is collapseable Inspector View.

Scroll View
-----------

[See the main test code](../test/main.nim)

Split View
-----------

A [view](../nimx/split_view.nim) with a movable divider between sections for resizing the sub-views.

```
import nimx / [ window, layout, button, text_field, split_view, scroll_view, context ]

let red = newColor(1, 0, 0)
let blue = newColor(0, 0, 1)
let yellow = newColor(1, 1, 0)

runApplication:
    let w = newWindow(newRect(50, 50, 500, 150))
    w.makeLayout: # DSL follows
      - SplitView:
        frame == inset(super, 10)

        - ScrollView:
          backgroundColor: blue
          size >= [200, 500]
          - View:
            backgroundColor: red
            size == [100, 900]

        - View:
          backgroundColor: yellow
          width >= 100
```          

Stack View
----------

A [vertical linear](../nimx/stack_view.nim) view.

Table View
----------

A [table or grid](../nimx/table_view.nim) view, with controls/view arranged in a rows and columns.
