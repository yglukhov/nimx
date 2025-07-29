import macros, times
import view, table_view_cell, text_field, context, app, view_event_handling, font, layout, kiwi, private/kiwi_vector_symbolics

type MenuItem* = ref object of RootObj
    title*: string
    children*: seq[MenuItem]
    # customView*: View
    action*: proc() {.gcsafe.}

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

proc minMenuWidth(item: MenuItem): Coord =
    let font = systemFont()
    for c in item.children:
        let sz = font.sizeOfString(c.title).width
        if sz > result: result = sz

proc newViewWithMenuItems(item: MenuItem, size: Size): MenuView =
    let width = max(size.width, minMenuWidth(item) + 20)
    result = MenuView.new(zeroRect)
    result.addConstraint(selfPHS.width == newExpression(width))
    result.item = item
    result.highlightedRow = -1
    var yOff = 0.Coord
    for i, item in item.children:
        var iv: View
        if item.title == "-":
            iv = SeparatorView.new(newRect(0, 0, width, size.height))
        else:
            let label = newLabel(newRect(0, 0, width, size.height))
            label.text = item.title
            iv = label
        iv.addConstraint(selfPHS.height == newExpression(size.height))
        iv.addConstraint(selfPHS.width == newExpression(width))
        iv.addConstraint(selfPHS.leading == superPHS.leading)
        iv.addConstraint(selfPHS.width == superPHS.width)
        iv.addConstraint(selfPHS.y == superPHS.y)
        iv.addConstraint(selfPHS.height == superPHS.height)
        let cell = newTableViewCell(iv)
        if i == 0:
            cell.addConstraint(selfPHS.y == superPHS.y)
        else:
            cell.addConstraint(selfPHS.y == prevPHS.bottom)
        cell.addConstraint(selfPHS.leading == superPHS.leading)
        cell.addConstraint(selfPHS.width == superPHS.width)

        cell.row = i
        cell.selected = false

        if item.children.len > 0:
            cell.makeLayout:
                - TriangleView:
                    width == self.height
                    height == super
                    trailing == super
                    y == super

        result.addSubview(cell)
        yOff += menuItemHeight

    if result.subviews.len != 0:
        result.subviews[^1].addConstraint(selfPHS.bottom == superPHS.bottom)

method draw(v: MenuView, r: Rect) =
    let c = currentContext()
    c.fillColor = newGrayColor(0.7)
    c.strokeWidth = 0
    c.drawRoundedRect(v.bounds, 5)

method draw(v: TriangleView, r: Rect) =
    let cell = v.enclosingTableViewCell()
    let c = currentContext()
    c.fillColor = blackColor()
    if not cell.isNil and cell.selected:
        c.fillColor = whiteColor()
    c.drawTriangle(v.bounds, 0)

method draw(v: SeparatorView, r: Rect) =
    let c = currentContext()
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

proc addOriginConstraints(m: MenuView, inView: View, desiredOrigin: Point) =
    # Add constraints necessary to display `m` at the `desiredOrigin` of `inView`,
    # but only if `m` fits in the window
    let w = inView.window
    var wp = inView.convertPointToWindow(desiredOrigin)
    m.addConstraint(modifyStrength(selfPHS.x == wp.x, MEDIUM))
    m.addConstraint(modifyStrength(selfPHS.y == wp.y, MEDIUM))
    m.addConstraint(selfPHS.leading >= w.layout.vars.leading)
    m.addConstraint(selfPHS.trailing <= w.layout.vars.trailing)
    m.addConstraint(selfPHS.top >= w.layout.vars.top)
    m.addConstraint(selfPHS.bottom <= w.layout.vars.bottom)

proc popupAtPoint*(m: MenuItem, v: View, p: Point, size: Size = newSize(150.0, menuItemHeight)) =
    let mv = newViewWithMenuItems(m, size)
    mv.addOriginConstraints(v, p)
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
                        let sub = newViewWithMenuItems(selectedItem, size)
                        var pt = newPoint(selectedCell.bounds.width, selectedCell.bounds.y)
                        sub.addOriginConstraints(selectedCell, pt)
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
