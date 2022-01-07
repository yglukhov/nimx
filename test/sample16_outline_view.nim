import strutils
import sample_registry
import variant
import nimx / [ outline_view, scroll_view, button, layout, text_field, table_view_cell ]

import intsets

type
  OutlineViewSampleView = ref object of View
    rootItem: Node

  Node = ref object
    text: string
    children: seq[Node]

method init(v: OutlineViewSampleView, r: Rect) =
  procCall v.View.init(r)

  v.rootItem = Node()
  for i in 0 .. 5:
    v.rootItem.children.add(Node(text: "Item " & $i))

  for i in 0 .. 3:
    v.rootItem.children[0].children.add(Node(text: "Item " & $i))

  for i in 0 .. 3:
    v.rootItem.children[3].children.add(Node(text: "Item " & $i))

  for i in 0 .. 3:
    v.rootItem.children[3].children[2].children.add(Node(text: "Item " & $i))

  v.makeLayout:
    - ScrollView:
      frame == inset(super, 0, 0, 0, 25)
      - OutlineView as outlineView:
        width == super
        defaultRowHeight: 20
        numberOfChildren do(i: Node, indexPath: IndexPath) -> int:
          i.children.len

        rootItem do() -> Node:
          v.rootItem

        childOfItem do(i: Node, indexPath: IndexPath) -> Node:
          i.children[indexPath[^1]]

        createCell do() -> TableViewCell:
          # Amalyze `c.col` to differentiate between columns
          result = newTableViewCell()
          result.makeLayout:
            - Label:
              frame == super

        configureCell do(n: Node, c: TableViewCell):
          # Amalyze `c.col` to differentiate between columns
          let l = Label(c.subviews[0])
          let s = n.text
          l.text = s

        onSelectionChange do():
          echo "Selection changed: ", outlineView.selectedRows

    # - View:
    #   frame == inset(super, 0, 0, 0, 25)
    #   backgroundColor: newColor(1, 0, 0)

    - Button:
      title: "+"
      frame == autoresizingFrame(0, 25, NaN, NaN, 25, 0)
      onAction:
        discard
        # var selection = outlineView.selectedIndexPaths(allowOverlap = true)

        # for indexPath in selection:
        #   let n = outlineView.itemAtIndexPath(Node, indexPath)
        #   let sz = n.children.len
        #   n.children.add(Node(text: "Node " & $sz))

        # outlineView.reloadIndexPaths(selection)

    - Button:
      title: "-"
      frame == autoresizingFrame(25, 25, NaN, NaN, 25, 0)
      onAction:
        discard
        # var selection = outlineView.selectedIndexPaths(allowOverlap = true)

        # for indexPath in selection:
        #   let n = outlineView.itemAtIndexPath(Node, indexPath)
        #   let sz = n.children.len
        #   n.children.add(Node(text: "Node " & $sz))

        # outlineView.reloadIndexPaths(selection)


  # outlineView.addSubview(asdf)
  
  outlineView.reloadData()
  outlineView.expandRow([0])
  outlineView.expandRow([3])
  outlineView.expandRow([3, 2])

registerSample(OutlineViewSampleView, "OutlineView")
