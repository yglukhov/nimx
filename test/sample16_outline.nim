import sample_registry
import nimx / [ view, outline_view, scroll_view, table_view_cell, text_field ]
import variant

type
    DataItem = ref object
        name: string
        children: seq[DataItem]
        parent: DataItem

type OutlineSampleView = ref object of View

proc addChild(p: DataItem, ch: DataItem): DataItem =
    p.children.add(ch)
    ch.parent = p
    result = p

method init*(v: OutlineSampleView, r: Rect) =
    procCall v.View.init(r)

    var outline = OutlineView.new(newRect(10.0, 10.0, 200.0, v.bounds.height - 10.0))
    outline.autoresizingMask={afFlexibleWidth, afFlexibleHeight}

    var scroll = newScrollView(outline)
    scroll.autoresizingMask={afFlexibleWidth, afFlexibleHeight}
    v.addSubview(scroll)

    var rootDataItem = DataItem(name: "root")
        .addChild(DataItem(name: "child0"))
        .addChild(
            DataItem(name: "child1")
                .addChild(DataItem(name: "subchild0"))
                .addChild(DataItem(name: "subchild1"))
        )
        .addChild(DataItem(name: "child2"))

    outline.numberOfChildrenInItem = proc(item: Variant, indexPath: openArray[int]): int =
        if indexPath.len == 0:
            return 1
        else:
            return item.get(DataItem).children.len

    outline.childOfItem = proc(item: Variant, indexPath: openArray[int]): Variant =
        if indexPath.len == 1:
            return newVariant(rootDataItem)
        else:
            let node = item.get(DataItem).children[indexPath[^1]]
            return newVariant(node)

    outline.createCell = proc(): TableViewCell =
        result = newTableViewCell(
            newLabel(newRect(0, 0, 200, 20))
        )

    outline.configureCell = proc(cell: TableViewCell, indexPath: openArray[int]) =
        let node = outline.itemAtIndexPath(indexPath).get(DataItem)
        let textField = TextField(cell.subviews[0])
        textField.text = node.name

    outline.onDragAndDrop = proc(fromPath, toPath: openArray[int]) =
        echo fromPath, " >> ", toPath
        var parentPos = @toPath[0..^2]
        let fromNode = outline.itemAtIndexPath(fromPath).get(DataItem)
        let toNode = outline.itemAtIndexPath(parentPos).get(DataItem)

        let fi = fromNode.parent.children.find(fromNode)
        fromNode.parent.children.delete(fi)
        fromNode.parent = toNode
        let toIndex = clamp(toPath[^1], 0, toNode.children.len)
        toNode.children.insert(fromNode, toIndex)
        outline.reloadData()

    outline.onSelectionChanged = proc() =
        let ip = outline.selectedIndexPath
        let node = if ip.len > 0:
                    outline.itemAtIndexPath(ip).get(DataItem)
                else:
                    nil
        if node.isNil:
            echo "select nil"
        else:
            echo "select ", node.name

    outline.reloadData()


method draw(v: OutlineSampleView, r: Rect) =
    v.setNeedsDisplay()


registerSample(OutlineSampleView, "Outline")
