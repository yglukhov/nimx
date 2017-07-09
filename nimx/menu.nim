import macros, times
import view, table_view_cell, text_field, context, app, view_event_handling

type MenuItem* = ref object of RootObj
    title*: string
    children*: seq[MenuItem]
    # customView*: View
    action*: proc()

type Menu* {.deprecated.}  = MenuItem

proc newMenuItem*(title: string): MenuItem =
    result.new()
    result.title = title

proc newMenu*(): MenuItem =
    result.new()

template `items=`*(m: MenuItem, items: seq[MenuItem]) = m.children = items
template `items`*(m: MenuItem): seq[MenuItem] = m.children

template menuItemOnAction(m: MenuItem, body: untyped) =
    m.action = proc() =
        body

proc menuItemAddSubmenu(m, s: MenuItem) =
    if m.children.isNil: m.children = @[s]
    else: m.children.add(s)

proc makeMenuAux(parentSym, b, res: NimNode) =
    for i in b:
        let s = genSym()
        i.expectKind(nnkPrefix)
        let name = i[1]
        let create = quote do:
            let `s` = newMenuItem(`name`)
        res.add(create)

        let tok = $i[0]
        assert(tok == "-" or tok == "+", "Unexpected token: " & tok)

        if i.len == 3:
            case tok
            of "-":
                res.add(newCall(bindSym"menuItemOnAction", s, i[2]))
            of "+":
                makeMenuAux(s, i[2], res)

        res.add(newCall(bindSym"menuItemAddSubmenu", parentSym, s))

macro makeMenu*(name: string, b: untyped): untyped =
    result = newNimNode(nnkStmtList)
    let i = genSym()
    let s = quote do:
        let `i` = newMenuItem(`name`)
    result.add(s)
    makeMenuAux(i, b, result)
    result.add(i)

type MenuView = ref object of View
    item: MenuItem
    highlightedRow: int

const menuItemHeight = 20.Coord

proc newViewWithMenuItems(item: MenuItem, size: Size): MenuView =
    result = MenuView.new(newRect(0, 0, size.width - 20.0, item.children.len.Coord * menuItemHeight))
    result.item = item
    result.highlightedRow = -1
    var yOff = 0.Coord
    for i, item in item.children:
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

proc popupAtPoint*(m: MenuItem, v: View, p: Point, size: Size = newSize(150.0, menuItemHeight)) =
    let mv = newViewWithMenuItems(m, size)
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
                    let item = mv.item.children[mv.highlightedRow]
                    if not item.action.isNil:
                        item.action()
                control = efcBreak
                mv.removeFromSuperview()
