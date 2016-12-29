import view
import table_view_cell
import text_field
import context
import app
import view_event_handling

import times

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
    highlightedRow: int

const menuItemHeight = 20.Coord

proc newViewWithMenuItems(items: seq[MenuItem], size: Size): MenuView =
    result = MenuView.new(newRect(0, 0, size.width - 20.0, items.len.Coord * menuItemHeight))
    result.menuItems = items
    result.highlightedRow = -1
    var yOff = 0.Coord
    for i, item in items:
        let label = newLabel(newRect(0, 0, size.width - 20.0, size.height))
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

proc popupAtPoint*(m: Menu, v: View, p: Point, size: Size = newSize(150.0, menuItemHeight)) =
    let mv = newViewWithMenuItems(m.items, size)
    var wp = v.convertPointToWindow(p)
    let win = v.window

    # If the menu is out of window bounds, move it inside
    if wp.x < win.bounds.x:
        wp.x = win.bounds.x
    elif wp.x + mv.frame.width > win.bounds.maxX:
        wp.x = win.bounds.maxX - mv.frame.width
    if wp.y < win.bounds.y:
        wp.y = win.bounds.y
    elif wp.y + mv.frame.height > win.bounds.maxY:
        wp.y = win.bounds.maxY - mv.frame.height

    mv.setFrameOrigin(wp)
    v.window.addSubview(mv)

    let popupTime = epochTime()

    mainApplication().pushEventFilter do(e: var Event, control: var EventFilterControl) -> bool:
        result = true
        let localPos = mv.convertPointFromWindow(e.position)
        if e.buttonState == bsDown:
            if not localPos.inRect(mv.bounds):
                control = efcBreak
                mv.removeFromSuperview()
        else:
            if mv.highlightedRow != -1:
                TableViewCell(mv.subviews[mv.highlightedRow]).selected = false

            mv.highlightedRow = int(localPos.y / menuItemHeight)

            if localPos.inRect(mv.bounds) and mv.highlightedRow >= 0 and mv.highlightedRow < mv.subviews.len:
                TableViewCell(mv.subviews[mv.highlightedRow]).selected = true
            else:
                mv.highlightedRow = -1
            v.setNeedsDisplay()

            if e.buttonState == bsUp and (epochTime() - popupTime) > 0.3:
                if mv.highlightedRow != -1:
                    let item = mv.menuItems[mv.highlightedRow]
                    if not item.action.isNil:
                        item.action()
                control = efcBreak
                mv.removeFromSuperview()
