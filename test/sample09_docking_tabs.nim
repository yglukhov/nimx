import random
import sample_registry
import nimx / [ view, button, layout ]
import nimx/editor/tab_view

type DockingTabsSampleView = ref object of View
    tabNameIndex: int

proc newTabTitle(v: DockingTabsSampleView): string =
    inc v.tabNameIndex
    result = "Tab " & $v.tabNameIndex

proc newRandomColor(): Color = newColor(rand(1.0), rand(1.0), rand(1.0), 1.0)

proc newTab(v: DockingTabsSampleView): View =
    result = View.new(zeroRect)
    const buttonSize = 20
    let pane = result

    proc indexOfPaneInTabView(): int =
        let tv = TabView(pane.superview)
        tv.tabIndex(pane)

    result.makeLayout:
        backgroundColor: newRandomColor()

        - Button:
            title: "+"
            onAction:
                let tv = TabView(pane.superview)
                let i = indexOfPaneInTabView() + 1
                tv.insertTab(i, v.newTabTitle(), v.newTab())
                tv.selectTab(i)
            leading == super + 5
            top == super + 5
            width == buttonSize
            height == buttonSize

        - Button:
            title: "-"
            onAction:
                let tv = TabView(pane.superview)
                if tv.tabsCount == 1:
                    tv.removeFromSplitViewSystem()
                else:
                    tv.removeTab(indexOfPaneInTabView())
            leading == prev.trailing + 5
            top == prev
            size == prev

        - Button:
            title: "c"
            onAction:
                pane.backgroundColor = newRandomColor()
            leading == prev.trailing + 5
            top == prev
            size == prev

    result.backgroundColor = newRandomColor()

method init(v: DockingTabsSampleView, r: Rect) =
    procCall v.View.init(r)
    v.makeLayout:
        - TabView as pane:
            dockingTabs: true
            userConfigurable: true
            origin == super
            size == super

    pane.addTab(v.newTabTitle(), v.newTab())

registerSample(DockingTabsSampleView, "Docking Tabs")
