import random
import sample_registry
import nimx / [ view, linear_layout, button ]
import nimx/editor/tab_view

type DockingTabsSampleView = ref object of View
    tabNameIndex: int

proc newTabTitle(v: DockingTabsSampleView, gfx: GraphicsContext): string =
    inc v.tabNameIndex
    result = "Tab " & $v.tabNameIndex

proc newRandomColor(): Color = newColor(rand(1.0), rand(1.0), rand(1.0), 1.0)

proc newTab(v: DockingTabsSampleView, gfx: GraphicsContext): View =
    result = View.new(gfx, newRect(0, 0, 100, 100))
    result.backgroundColor = newRandomColor()

    const buttonSize = 20
    let pane = result

    proc indexOfPaneInTabView(): int =
        let tv = TabView(pane.superview)
        for i in 0 ..< tv.tabsCount:
            if tv.viewOfTab(i) == pane:
                return i
        result = -1

    let addButton = Button.new(gfx, newRect(5, 5, buttonSize, buttonSize))
    addButton.title = "+"
    addButton.onAction do():
        let tv = TabView(pane.superview)
        let i = indexOfPaneInTabView() + 1
        tv.insertTab(i, v.newTabTitle(gfx), v.newTab(gfx))
        tv.selectTab(i)
    result.addSubview(addButton)

    let removeButton = Button.new(gfx, newRect(addButton.frame.maxX + 2, 5, buttonSize, buttonSize))
    removeButton.title = "-"
    removeButton.onAction do():
        let tv = TabView(pane.superview)
        if tv.tabsCount == 1:
            tv.removeFromSplitViewSystem()
        else:
            tv.removeTab(indexOfPaneInTabView())
    result.addSubview(removeButton)

    let c = Button.new(gfx, newRect(removeButton.frame.maxX + 2, 5, buttonSize, buttonSize))
    c.title = "c"
    c.onAction do():
        pane.backgroundColor = newRandomColor()
    result.addSubview(c)

method init(v: DockingTabsSampleView, gfx: GraphicsContext, r: Rect) =
    procCall v.View.init(gfx, r)
    let pane = TabView.new(gfx, v.bounds)
    pane.dockingTabs = true
    pane.addTab(v.newTabTitle(gfx), v.newTab(gfx))
    pane.resizingMask = "wh"
    pane.userConfigurable = true
    v.addSubview(pane)

registerSample(DockingTabsSampleView, "Docking Tabs")
