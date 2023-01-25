import math
import kiwi
import nimx / [view, context, matrixes, font, linear_layout, button, menu, split_view, layout_vars]
import nimx / [ view_event_handling, window_event_handling ]

type
    Tab = tuple[title: string, view: View, frame: Rect]
    TabBarOrientation {.pure.} = enum
        top, left, bottom, right
    TabDraggingView = ref object of View
        title: string

type TabView* = ref object of View
    tabs: seq[Tab]
    tabBarThickness: Coord
    mTabBarOrientation: TabBarOrientation
    selectedTab: int
    mouseTracker: proc(e: Event): bool {.gcsafe.}
    tabFramesValid: bool
    dockingTabs*: bool
    configurationButton: Button
    onSplit*: proc(v: TabView) {.gcsafe.}
    onRemove*: proc(v: TabView) {.gcsafe.}
    onClose*: proc(v: View) {.gcsafe.}
    subviewConstraintProtos: seq[Constraint]

proc contentFrame(v: TabView): Rect =
    result = v.bounds
    case v.mTabBarOrientation
    of TabBarOrientation.top:
        result.origin.y += v.tabBarThickness
        result.size.height -= v.tabBarThickness
    of TabBarOrientation.bottom:
        result.size.height -= v.tabBarThickness
    of TabBarOrientation.left:
        result.origin.x += v.tabBarThickness
        result.size.width -= v.tabBarThickness
    of TabBarOrientation.right:
        result.size.width -= v.tabBarThickness

proc updateSubviewConstraintProtos(v: TabView) =
    v.subviewConstraintProtos.setLen(0)
    template orientationOption(id, value: untyped) =
        if v.mTabBarOrientation == TabBarOrientation.id:
            v.subviewConstraintProtos.add(selfPHS.id == superPHS.id + value)
        else:
            v.subviewConstraintProtos.add(selfPHS.id == superPHS.id)
    orientationOption(top, v.tabBarThickness)
    orientationOption(bottom, -v.tabBarThickness)
    orientationOption(left, v.tabBarThickness)
    orientationOption(right, -v.tabBarThickness)

method init*(v: TabView, r: Rect) =
    procCall v.View.init(r)
    v.tabs = @[]
    v.tabBarThickness = 25
    v.mTabBarOrientation = TabBarOrientation.top
    v.selectedTab = -1
    v.backgroundColor = newGrayColor(0.5)

proc selectedView*(v: TabView): View =
    if v.selectedTab < 0 or v.selectedTab > v.tabs.high:
        nil
    else:
        v.tabs[v.selectedTab].view

proc updateSelectedViewFrame(v: TabView) =
    let sv = v.selectedView
    if not sv.isNil:
        if v.usesNewLayout:
            sv.removeConstraints(v.subviewConstraintProtos)
            v.updateSubviewConstraintProtos()
            sv.addConstraints(v.subviewConstraintProtos)
        else:
            sv.setFrame(v.contentFrame)

proc updateConfigurationButtonLayout(v: TabView) =
    let b = v.configurationButton
    if not b.isNil:
        if v.usesNewLayout:
            b.removeConstraints(b.constraints)
            b.addConstraint(selfPHS.width == 15)
            b.addConstraint(selfPHS.height == 15)
            const offs = 5
            case v.mTabBarOrientation
            of TabBarOrientation.top:
                b.addConstraint(selfPHS.trailing == superPHS.trailing - offs)
                b.addConstraint(selfPHS.top == offs)
            of TabBarOrientation.bottom:
                b.addConstraint(selfPHS.trailing == superPHS.trailing - offs)
                b.addConstraint(selfPHS.bottom == superPHS.bottom - offs)
            of TabBarOrientation.left:
                b.addConstraint(selfPHS.leading == superPHS.leading + offs)
                b.addConstraint(selfPHS.bottom == superPHS.bottom - offs)
            of TabBarOrientation.right:
                b.addConstraint(selfPHS.trailing == superPHS.trailing - offs)
                b.addConstraint(selfPHS.bottom == superPHS.bottom - offs)
        else:
            case v.mTabBarOrientation
            of TabBarOrientation.top:
                b.setFrameOrigin(newPoint(v.bounds.maxX - 25, 2))
                b.resizingMask = "lb"
            of TabBarOrientation.bottom:
                b.setFrameOrigin(newPoint(v.bounds.maxX - 25, v.bounds.maxY - 20))
                b.resizingMask = "lt"
            of TabBarOrientation.left:
                b.setFrameOrigin(newPoint(v.bounds.minX + 2, v.bounds.maxY - 20))
                b.resizingMask = "rt"
            of TabBarOrientation.right:
                b.setFrameOrigin(newPoint(v.bounds.maxX - 25, v.bounds.maxY - 20))
                b.resizingMask = "lt"

template tabBarOrientation*(v: TabView): TabBarOrientation = v.mTabBarOrientation
proc `tabBarOrientation=`*(v: TabView, o: TabBarOrientation) =
    v.mTabBarOrientation = o
    v.tabFramesValid = false
    v.updateSelectedViewFrame()
    v.updateConfigurationButtonLayout()

proc selectTabAux(v: TabView, i: int) =
    assert(i >= -1 and i < v.tabs.len)
    if i == v.selectedTab: return
    assert(v.selectedTab != i)
    var sv = v.selectedView
    if not sv.isNil:
        sv.removeConstraints(v.subviewConstraintProtos)
        sv.removeFromSuperview()
    v.selectedTab = i
    sv = v.selectedView
    if not sv.isNil:
        if v.usesNewLayout:
            if v.subviewConstraintProtos.len == 0:
                v.updateSubviewConstraintProtos()
            sv.addConstraints(v.subviewConstraintProtos)
        else:
            sv.setFrame(v.contentFrame)
        v.addSubview(sv)
        discard sv.makeFirstResponder()

proc selectTab*(v: TabView, i: int) =
    selectTabAux(v, i)

proc insertTab*(v: TabView, i: int, title: string, view: View) =
    var t: Tab
    t.title = title
    t.view = view
    view.removeFromSuperview()
    view.autoresizingMask = {afFlexibleWidth, afFlexibleHeight}
    v.tabs.insert(t, i)
    if i <= v.selectedTab: inc v.selectedTab
    v.tabFramesValid = false
    if v.tabs.len == 1:
        v.selectTab(0)

proc tabIndex*(v: TabView, sv: View): int=
    result = -1
    for i, t in v.tabs:
        if t.view == sv:
            return i

proc tabIndex*(v: TabView, title: string): int=
    result = -1
    for i, t in v.tabs:
        if t.title == title:
            return i

proc addTab*(v: TabView, title: string, view: View) {.inline.} =
    v.insertTab(v.tabs.len, title, view)

proc removeTab*(v: TabView, i: int) =
    if i == v.selectedTab:
        var nextSelectedTab = i + 1
        if nextSelectedTab == v.tabs.len:
            nextSelectedTab = i - 1
        v.selectTab(nextSelectedTab)

    if i < v.selectedTab: dec v.selectedTab
    v.tabs.delete(i)
    v.tabFramesValid = false

proc removeFromSplitViewSystem*(v: View)
proc userConfigurable*(v: TabView): bool = not v.configurationButton.isNil
proc `userConfigurable=`*(v: TabView, b: bool) =
    if b and v.configurationButton.isNil:
        v.configurationButton = Button.new(newRect(0, 0, 15, 15))
        v.configurationButton.title = "c"
        v.updateConfigurationButtonLayout()
        v.configurationButton.onAction do():
            let m = newMenu()
            template orientationItem(title: string, orientation: TabBarOrientation) =
                let tm = newMenuItem("Tabs - " & title)
                tm.action = proc() =
                    v.tabBarOrientation = orientation
                m.items.add(tm)
            orientationItem("Top", TabBarOrientation.top)
            orientationItem("Left", TabBarOrientation.left)
            orientationItem("Right", TabBarOrientation.right)
            orientationItem("Bottom", TabBarOrientation.bottom)

            if v.tabs.len > 1:
                let tm = newMenuItem("Close current")
                tm.action = proc() =
                    if not v.onClose.isNil:
                        v.onClose(v.selectedView())
                    v.removeTab(v.selectedTab)

                m.items.add(tm)

            m.popupAtPoint(v.configurationButton, zeroPoint)
        v.addSubview(v.configurationButton)
    elif not b and not v.configurationButton.isNil:
        v.configurationButton.removeFromSuperview()
        v.configurationButton = nil

proc updateTabFrames(v: TabView) =
    let f = systemFont()
    case v.tabBarOrientation
    of TabBarOrientation.top, TabBarOrientation.bottom:
        var top = 0.Coord
        if v.tabBarOrientation == TabBarOrientation.bottom:
            top = v.bounds.maxY - v.tabBarThickness
        for i in 0 .. v.tabs.high:
            v.tabs[i].frame.origin.y = top
            if i == 0:
                v.tabs[i].frame.origin.x = 0
            else:
                v.tabs[i].frame.origin.x = v.tabs[i - 1].frame.maxX
            v.tabs[i].frame.size.width = f.sizeOfString(v.tabs[i].title).width + 10
            v.tabs[i].frame.size.height = v.tabBarThickness
    of TabBarOrientation.left, TabBarOrientation.right:
        var left = 0.Coord
        if v.tabBarOrientation == TabBarOrientation.right:
            left = v.bounds.maxX - v.tabBarThickness
        for i in 0 .. v.tabs.high:
            v.tabs[i].frame.origin.x = left
            if i == 0:
                v.tabs[i].frame.origin.y = 0
            else:
                v.tabs[i].frame.origin.y = v.tabs[i - 1].frame.maxY
            v.tabs[i].frame.size.height = f.sizeOfString(v.tabs[i].title).width + 10
            v.tabs[i].frame.size.width = v.tabBarThickness

proc tabsCount*(v: TabView): int = v.tabs.len
proc titleOfTab*(v: TabView, i: int): string = v.tabs[i].title
proc setTitleOfTab*(v: TabView, t: string, i: int) =
    v.tabs[i].title = t
    v.tabFramesValid = false
proc viewOfTab*(v: TabView, i: int): View = v.tabs[i].view

template updateTabFramesIfNeeded(v: TabView) =
    if not v.tabFramesValid:
        v.updateTabFrames()

method draw*(v: TabView, r: Rect) =
    procCall v.View.draw(r)
    v.updateTabFramesIfNeeded()
    let c = currentContext()
    let f = systemFont()
    for i in 0 .. v.tabs.high:
        let t = v.tabs[i].title
        if i == v.selectedTab:
            c.fillColor = newGrayColor(0.2)
            c.drawRect(v.tabs[i].frame)
            c.fillColor = newGrayColor(0.8)
        else:
            c.fillColor = blackColor()

        if v.tabBarOrientation == TabBarOrientation.left or v.tabBarOrientation == TabBarOrientation.right:
            var tmpTransform = c.transform
            tmpTransform.translate(newVector3(v.tabs[i].frame.x + v.tabBarThickness, v.tabs[i].frame.y))
            tmpTransform.rotateZ(PI/2)
            c.withTransform tmpTransform:
                c.drawText(f, newPoint(5, 5), t)
        else:
            c.drawText(f, newPoint(v.tabs[i].frame.x + 5, v.tabs[i].frame.y + 5), t)

proc tabBarRect(v: TabView): Rect =
    result = v.bounds
    case v.tabBarOrientation
    of TabBarOrientation.top:
        result.size.height = v.tabBarThickness
    of TabBarOrientation.bottom:
        result.origin.y = result.maxY - v.tabBarThickness
        result.size.height = v.tabBarThickness
    of TabBarOrientation.left:
        result.size.width = v.tabBarThickness
    of TabBarOrientation.right:
        result.origin.x = result.maxX - v.tabBarThickness
        result.size.width = v.tabBarThickness

proc tabIndexAtPoint(v: TabView, p: Point): int =
    v.updateTabFramesIfNeeded()
    for i in 0 .. v.tabs.high:
        if p.inRect(v.tabs[i].frame):
            return i
    result = -1

proc findSubviewOfTypeAtPointAux[T](v: View, p: Point): T =
    for i in countdown(v.subviews.len - 1, 0):
        let s = v.subviews[i]
        var pp = s.convertPointFromParent(p)
        if pp.inRect(s.bounds):
            result = findSubviewOfTypeAtPointAux[T](s, pp)
            if not result.isNil:
                break
    if result.isNil and v of T:
        result = T(v)

proc findSubviewOfTypeAtPoint[T](v: View, p: Point): T =
    result = findSubviewOfTypeAtPointAux[T](v, p)
    if not result.isNil and View(result) == v: result = nil

proc newDraggingView(tab: Tab): TabDraggingView =
    result = TabDraggingView.new(newRect(0, 0, 400, 400))
    result.title = tab.title
    tab.view.setFrame(newRect(0, 25, 400, 400 - 25))
    result.addSubview(tab.view)

method draw(v: TabDraggingView, r: Rect) =
    procCall v.View.draw(r)
    let c = currentContext()
    let f = systemFont()
    var titleRect: Rect
    titleRect.size.width = f.sizeOfString(v.title).width + 10
    titleRect.size.height = 25
    c.fillColor = newColor(0.4, 0.4, 0.4)
    c.drawRect(titleRect)
    c.fillColor = newColor(1, 0, 0)
    c.drawText(f, newPoint(5, 0), v.title)

proc newTabViewForSplit(sz: Size, tab: Tab, prototype: TabView): TabView =
    result = TabView.new(newRect(zeroPoint, sz))
    result.addTab(tab.title, tab.view)
    result.dockingTabs = prototype.dockingTabs
    result.tabBarOrientation = prototype.tabBarOrientation
    result.userConfigurable = prototype.userConfigurable

proc newSplitView(r: Rect, horizontal: bool): LinearLayout =
    result = LinearLayout.new(r)
    result.horizontal = horizontal
    result.autoresizingMask = {afFlexibleWidth, afFlexibleHeight}
    result.userResizeable = true

proc onlyTabViewsInSplitView(sv: View): bool =
    for v in sv.subviews:
        if not (v of TabView): return false
    return true

proc splitNew(v: TabView, horizontally, before: bool, tab: Tab) =
    let s = v.superview
    var sz = v.frame.size
    var dividerPos: Coord
    if horizontally:
        sz.width /= 2
        dividerPos = sz.width
    else:
        sz.height /= 2
        dividerPos = sz.height

    let ntv = newTabViewForSplit(zeroSize, tab, v)
    ntv.onSplit = v.onSplit
    ntv.onRemove = v.onRemove
    ntv.onClose = v.onClose
    if not ntv.onSplit.isNil:
        ntv.onSplit(ntv)

    if (s of SplitView) and SplitView(s).vertical != horizontally and onlyTabViewsInSplitView(s):
        if before:
            s.insertSubviewBefore(ntv, v)
        else:
            s.insertSubviewAfter(ntv, v)

    else:
        let vl = SplitView.new(zeroRect)
        vl.vertical = not horizontally
        vl.addConstraints(v.constraints)
        s.replaceSubview(v, vl)
        v.removeConstraints(v.constraints)
        if before:
            vl.addSubview(ntv)
            vl.addSubview(v)
        else:
            vl.addSubview(v)
            vl.addSubview(ntv)
        vl.setDividerPosition(dividerPos, 0)

proc splitOld(v: TabView, horizontally, before: bool, tab: Tab) =
    let s = v.superview

    var sz = v.frame.size
    if horizontally:
        sz.width /= 2
    else:
        sz.height /= 2

    let ntv = newTabViewForSplit(sz, tab, v)
    ntv.onSplit = v.onSplit
    ntv.onRemove = v.onRemove
    ntv.onClose = v.onClose
    if not ntv.onSplit.isNil:
        ntv.onSplit(ntv)

    if (s of LinearLayout) and LinearLayout(s).horizontal == horizontally and onlyTabViewsInSplitView(s):
        v.setFrameSize(sz)
        if before:
            s.insertSubviewBefore(ntv, v)
        else:
            s.insertSubviewAfter(ntv, v)
    else:
        let fr = v.frame
        let vl = newSplitView(fr, horizontally)
        s.replaceSubview(v, vl)
        v.setFrameSize(sz)
        if before:
            vl.addSubview(ntv)
            vl.addSubview(v)
        else:
            vl.addSubview(v)
            vl.addSubview(ntv)
        vl.setFrame(fr)

proc split*(v: TabView, horizontally, before: bool, tab: Tab) =
    if v.usesNewLayout:
        v.splitNew(horizontally, before, tab)
    else:
        v.splitOld(horizontally, before, tab)

proc removeFromSplitViewSystem*(v: View) =
    let newLayout = v.usesNewLayout
    var s = v
    while not s.isNil and ((not newLayout and s.superview of LinearLayout) or (newLayout and s.superview of SplitView)) and s.superview.subviews.len == 1:
        s = s.superview
    s.removeFromSuperview()

proc trackDocking(v: TabView, tab: int): proc(e: Event): bool {.gcsafe.} =
    var trackedTab = v.tabs[tab]
    var tabOwner = v
    var indexOfTabInOwner = tab
    var draggingView: View
    var dropOverlayView = View.new(zeroRect)
    dropOverlayView.backgroundColor = newColor(0, 0, 1, 0.5)

    const margin = 50

    result = proc(e: Event): bool =
        case e.buttonState
        of bsDown:
            result = true
        of bsUnknown:
            if not tabOwner.isNil:
                if not tabOwner.convertPointFromWindow(e.position).inRect(tabOwner.tabBarRect):
                    tabOwner.removeTab(indexOfTabInOwner)
                    tabOwner = nil

            let htv = findSubviewOfTypeAtPoint[TabView](e.window, e.position)
            if not htv.isNil:
                let htvp = htv.convertPointFromWindow(e.position)
                if htvp.inRect(htv.tabBarRect):
                    dropOverlayView.removeFromSuperview()

                    var ti = htv.tabIndexAtPoint(htv.convertPointFromWindow(e.position))
                    if tabOwner != htv or ti != indexOfTabInOwner:
                        if not tabOwner.isNil:
                            tabOwner.removeTab(indexOfTabInOwner)
                        if ti == -1: ti = htv.tabs.len
                        htv.insertTab(ti, trackedTab.title, trackedTab.view)
                        tabOwner = htv
                        indexOfTabInOwner = ti
                        htv.selectTab(indexOfTabInOwner)
                else:
                    var overlayRect: Rect
                    if htvp.x > margin and htvp.x < htv.bounds.maxX - margin:
                        if htvp.y > htv.tabBarThickness and htvp.y < margin:
                            overlayRect = newRect(0, 0, htv.bounds.width, margin)
                        elif htvp.y > htv.bounds.maxY - margin:
                            overlayRect = newRect(0, htv.bounds.maxY - margin, htv.bounds.width, margin)
                    elif htvp.y > margin and htvp.y < htv.bounds.maxY - margin:
                        if htvp.x < margin:
                            overlayRect = newRect(0, 0, margin, htv.bounds.height)
                        elif htvp.x > htv.bounds.maxX - margin:
                            overlayRect = newRect(htv.bounds.maxX - margin, 0, margin, htv.bounds.height)
                    if overlayRect != zeroRect:
                        overlayRect = htv.convertRectToWindow(overlayRect)
                        if v.usesNewLayout:
                            dropOverlayView.removeConstraints(dropOverlayView.constraints)
                            dropOverlayView.addConstraints(constraintsForFixedFrame(overlayRect, v.window.bounds.size, {afFlexibleHeight, afFlexibleWidth}))
                        else:
                            dropOverlayView.setFrame(overlayRect)
                        v.window.addSubview(dropOverlayView)
                    else:
                        dropOverlayView.removeFromSuperview()

            if not tabOwner.isNil and not draggingView.isNil:
                draggingView.removeFromSuperview()
                draggingView = nil
            elif tabOwner.isNil and draggingView.isNil:
                # Create dragging view
                draggingView = newDraggingView(trackedTab)
                e.window.addSubview(draggingView)

            if not draggingView.isNil:
                draggingView.setFrameOrigin(e.position)

            result = true
        of bsUp:
            dropOverlayView.removeFromSuperview()
            if not draggingView.isNil:
                draggingView.removeFromSuperview()
            if tabOwner.isNil:
                let htv = findSubviewOfTypeAtPoint[TabView](e.window, e.position)
                var done = false
                if not htv.isNil:
                    let htvp = htv.convertPointFromWindow(e.position)
                    if htvp.x > margin and htvp.x < htv.bounds.maxX - margin:
                        if htvp.y > htv.tabBarThickness and htvp.y < margin:
                            htv.split(false, true, trackedTab)
                            done = true
                        elif htvp.y > htv.bounds.maxY - margin:
                            htv.split(false, false, trackedTab)
                            done = true
                    elif htvp.y > margin and htvp.y < htv.bounds.maxY - margin:
                        if htvp.x < margin:
                            htv.split(true, true, trackedTab)
                            done = true
                        elif htvp.x > htv.bounds.maxX - margin:
                            htv.split(true, false, trackedTab)
                            done = true
                if not done:
                    v.insertTab(tab, trackedTab.title, trackedTab.view)
                    v.selectTab(tab)

            if v.tabsCount == 0:
                if not v.onRemove.isNil:
                    v.onRemove(v)
                v.removeFromSplitViewSystem()

method onTouchEv*(v: TabView, e: var Event): bool =
    result = procCall v.View.onTouchEv(e)
    case e.buttonState
    of bsDown:
        let t = v.tabIndexAtPoint(e.localPosition)
        if t != -1:
            v.selectTab(t)
            result = true
            if v.dockingTabs:
                v.mouseTracker = v.trackDocking(t)
    else:
        discard
    if not v.mouseTracker.isNil:
        result = v.mouseTracker(e)
        if not result:
            v.mouseTracker = nil

registerClass(TabView)
