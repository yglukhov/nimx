import view
import table_view_cell
import text_field
import context
import app
import view_event_handling

type MenuItem* = ref object of RootObj
    title*: string
    subitems*: seq[MenuItem]
    customView*: View
    action*: proc()

proc newMenuItem*(title: string): MenuItem =
    result.new()
    result.title = title

type Menu* = ref object of RootObj
    items*: seq[MenuItem]

proc newMenu*(): Menu =
    result.new()

type MenuView = ref object of View
    menuItems: seq[MenuItem]

const menuItemHeight = 20.Coord

proc newViewWithMenuItems(items: seq[MenuItem]): MenuView =
    result = MenuView.new(newRect(0, 0, 150, items.len.Coord * menuItemHeight))
    result.menuItems = items
    var yOff = 0.Coord
    for i, item in items:
        let label = newLabel(newRect(0, 0, 150, menuItemHeight))
        label.text = item.title
        let cell = newTableViewCell(label)
        cell.setFrameOrigin(newPoint(0, yOff))
        cell.row = i
        cell.selected = false
        result.addSubview(cell)
        yOff += menuItemHeight

method draw(v: MenuView, r: Rect) =
    let c = currentContext()
    c.fillColor = newGrayColor(0.7)
    c.strokeWidth = 0
    c.drawRoundedRect(v.bounds, 5)

proc popupAtPoint*(m: Menu, v: View, p: Point) =
    let mv = newViewWithMenuItems(m.items)
    mv.setFrameOrigin(v.convertPointToWindow(p))
    v.window.addSubview(mv)
    mainApplication().pushEventFilter do(e: var Event, control: var EventFilterControl) -> bool:
        e.localPosition = mv.convertPointFromWindow(e.position)
        if e.buttonState == bsDown:
            if not e.localPosition.inRect(mv.bounds):
                control = efcBreak
                mv.removeFromSuperview()
        else:
            var highlightedRow = int(e.localPosition.y / menuItemHeight)
            for sv in mv.subviews:
                TableViewCell(sv).selected = false

            if e.localPosition.inRect(mv.bounds) and highlightedRow >= 0 and highlightedRow < mv.subviews.len:
                TableViewCell(mv.subviews[highlightedRow]).selected = true
            else:
                highlightedRow = -1
            v.setNeedsDisplay()

            if e.buttonState == bsUp:
                if highlightedRow != -1:
                    let item = mv.menuItems[highlightedRow]
                    if not item.action.isNil:
                        item.action()
                control = efcBreak
                mv.removeFromSuperview()
