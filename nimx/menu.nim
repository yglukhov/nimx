import macros, times
import view, table_view_cell, text_field, context, app, view_event_handling, font

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
    m.children.add(s)

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

################################################################################
# Menu displaying

type
    MenuView = ref object of View
        item: MenuItem
        highlightedRow: int
        submenu: MenuView

    TriangleView = ref object of View
    SeparatorView = ref object of View

const menuItemHeight = 20.Coord

proc minMenuWidth(gfxCtx: GraphicsContext, item: MenuItem): Coord =
    template fontCtx: untyped = gfxCtx.fontCtx
    template gl: untyped = gfxCtx.gl
    let font = systemFont(fontCtx)
    for c in item.children:
        let sz = sizeOfString(fontCtx, gl, font, c.title).width
        if sz > result: result = sz

proc newViewWithMenuItems(w: Window, ctx: GraphicsContext, item: MenuItem, size: Size): MenuView =
    let width = max(size.width, minMenuWidth(ctx, item) + 20)
    result = MenuView.new(w, newRect(0, 0, width, item.children.len.Coord * menuItemHeight))
    result.item = item
    result.highlightedRow = -1
    var yOff = 0.Coord
    for i, item in item.children:
        var cell: TableViewCell
        if item.title == "-":
            let sep = SeparatorView.new(w, newRect(0, 0, width, size.height))
            cell = newTableViewCell(w, sep)
        else:
            let label = newLabel(w, newRect(0, 0, width, size.height))
            label.text = item.title
            cell = newTableViewCell(w, label)

        cell.setFrameOrigin(newPoint(0, yOff))
        cell.row = i
        cell.selected = false

        if item.children.len > 0:
            let triangleView = TriangleView.new(w, newRect(width - 20, 0, 20, menuItemHeight))
            cell.addSubview(triangleView)

        result.addSubview(cell)
        yOff += menuItemHeight

method draw(v: MenuView, r: Rect) =
    let c = v.window.gfxCtx
    c.fillColor = newGrayColor(0.7)
    c.strokeWidth = 0
    c.drawRoundedRect(v.bounds, 5)

method draw(v: TriangleView, r: Rect) =
    let cell = v.enclosingTableViewCell()
    let c = v.window.gfxCtx
    c.fillColor = blackColor()
    if not cell.isNil and cell.selected:
        c.fillColor = whiteColor()
    c.drawTriangle(v.bounds, 0)

method draw(v: SeparatorView, r: Rect) =
    let c = v.window.gfxCtx
    c.fillColor = newGrayColor(0.2)
    c.strokeWidth = 0
    var r = v.bounds
    r.origin.x += 5
    r.origin.y += r.height / 2 - 1
    r.size.height = 1
    r.size.width -= 10
    c.drawRect(r)

proc removeMenuView(v: MenuView) =
    var v = v
    while not v.isNil:
        v.removeFromSuperview()
        v = v.submenu

proc popupAtPoint*(m: MenuItem, v: View, p: Point, size: Size = newSize(150.0, menuItemHeight)) =
    let ctx = v.window.gfxCtx
    let mv = newViewWithMenuItems(v.window, ctx, m, size)
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
        var localPos: Point

        var curMv = mv
        while true:
            localPos = curMv.convertPointFromWindow(e.position)
            if localPos in curMv.bounds or curMv.submenu.isNil:
                break
            curMv = curMv.submenu

        if e.buttonState == bsDown:
            if localPos notin curMv.bounds:
                control = efcBreak
                mv.removeMenuView()
        else:
            var newHighlightedRow = int(localPos.y / menuItemHeight)
            if localPos notin curMv.bounds or
                    newHighlightedRow < 0 or newHighlightedRow >= curMv.subviews.len or
                    curMv.item.children[newHighlightedRow].title == "-":
                newHighlightedRow = -1

            if curMv.highlightedRow != newHighlightedRow:
                curMv.submenu.removeMenuView()
                curMv.submenu = nil

                if curMv.highlightedRow != -1:
                    TableViewCell(curMv.subviews[curMv.highlightedRow]).selected = false

                curMv.highlightedRow = newHighlightedRow

                if newHighlightedRow != -1:
                    let selectedCell = TableViewCell(curMv.subviews[newHighlightedRow])
                    selectedCell.selected = true
                    let selectedItem = curMv.item.children[newHighlightedRow]

                    if selectedItem.children.len > 0:
                        # Create submenu view
                        let sub = newViewWithMenuItems(win, ctx, selectedItem, size)
                        var pt = newPoint(selectedCell.bounds.width, selectedCell.bounds.y)
                        pt = selectedCell.convertPointToWindow(pt)
                        sub.setFrameOrigin(pt)
                        v.window.addSubview(sub)
                        curMv.submenu = sub

            v.setNeedsDisplay()

            if e.buttonState == bsUp and (epochTime() - popupTime) > 0.3:
                if curMv.highlightedRow != -1:
                    let item = curMv.item.children[curMv.highlightedRow]
                    if not item.action.isNil:
                        item.action()
                control = efcBreak
                mv.removeMenuView()
