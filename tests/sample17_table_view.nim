import strutils, algorithm, intsets
import sample_registry
import variant
import nimx / [ table_view, scroll_view, button, layout, text_field, table_view_cell ]

type
  TableViewSampleView = ref object of View
    data: seq[string]

proc delete[T](s: var seq[T], indexes: IntSet) =
  var sortedIndexes = newSeq[int](indexes.len)
  var i = 0
  for ii in indexes:
    sortedIndexes[i] = ii
    inc i

  sortedIndexes.sort()
  for i in countdown(sortedIndexes.high, sortedIndexes.low):
    s.delete(sortedIndexes[i])

method init(v: TableViewSampleView) =
  procCall v.View.init()

  for i in 1 .. 20:
    v.data.add("Item " & $i)

  v.makeLayout:
    - ScrollView:
      frame == inset(super, 0, 0, 0, 25)
      - TableView as tableView:
        width == super
        selectionMode: smMultipleSelection
        defaultRowHeight: 20
        numberOfRows do() -> int:
          v.data.len

        createCell do(column: int) -> TableViewCell:
          result = newTableViewCell()
          result.makeLayout:
            - Label:
              frame == super

        configureCell do(c: TableViewCell):
          # Amalyze `c.col` to differentiate between columns
          let l = Label(c.subviews[0])
          l.text = v.data[c.row]

        onSelectionChange do():
          echo "Selection changed: ", tableView.selectedRows

    # - View:
    #   frame == inset(super, 0, 0, 0, 25)
    #   backgroundColor: newColor(1, 0, 0)

    - Button:
      title: "+"
      frame == autoresizingFrame(0, 25, NaN, NaN, 25, 0)
      onAction:
        v.data.add("Item " & $(v.data.len + 1))
        tableView.reloadData()

    - Button:
      title: "-"
      frame == autoresizingFrame(25, 25, NaN, NaN, 25, 0)
      onAction:
        echo "selected rows: ", tableView.selectedRows
        v.data.delete(tableView.selectedRows)
        tableView.clearSelection()
        tableView.reloadData()
        # var selection = tableView.selectedIndexPaths(allowOverlap = true)

        # for indexPath in selection:
        #   let n = tableView.itemAtIndexPath(Node, indexPath)
        #   let sz = n.children.len
        #   n.children.add(Node(text: "Node " & $sz))

        # tableView.reloadIndexPaths(selection)

  tableView.reloadData()

registerSample(TableViewSampleView, "TableView")
