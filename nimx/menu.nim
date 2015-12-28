import view
import window
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

proc startTrackingMouse(v: MenuView) =
    var currentMenuView = v
    var highlightedRow = -1
    mainApplication().pushEventFilter do(e: var Event, c: var EventFilterControl) -> bool:
        result = true
        if e.isPointingEvent():
            e.localPosition = currentMenuView.convertPointFromWindow(e.position)
            var newHighlightedRow = -1
            if e.localPosition.inRect(currentMenuView.bounds):
                newHighlightedRow = int(e.localPosition.y / menuItemHeight)
            if newHighlightedRow != highlightedRow:
                if highlightedRow >= 0 and highlightedRow < currentMenuView.subviews.len:
                    TableViewCell(currentMenuView.subviews[highlightedRow]).selected = false
                if newHighlightedRow >= 0 and newHighlightedRow < currentMenuView.subviews.len:
                    TableViewCell(currentMenuView.subviews[newHighlightedRow]).selected = true
                currentMenuView.setNeedsDisplay()
                highlightedRow = newHighlightedRow

            if e.isButtonDownEvent():
                if highlightedRow >= 0 and highlightedRow < currentMenuView.subviews.len:
                    let item = currentMenuView.menuItems[highlightedRow]
                    if not item.action.isNil:
                        item.action()
                currentMenuView.removeFromSuperview()
                c = efcBreak

method draw(v: MenuView, r: Rect) =
    let c = currentContext()
    c.fillColor = newGrayColor(0.7)
    c.strokeWidth = 0
    c.drawRoundedRect(v.bounds, 5)

proc popupAtPoint*(m: Menu, v: View, p: Point) =
    let mv = newViewWithMenuItems(m.items)
    mv.setFrameOrigin(v.convertPointToWindow(p))
    v.window.addSubview(mv)
    mv.startTrackingMouse()
